import AVFoundation
import CoreVideo
import Foundation
import ImageIO
import SwiftUI

/// Owns the capture session for the three camera missions.
///
/// Not main-actor isolated: session configuration blocks for tens of milliseconds and frame
/// delivery arrives on AVFoundation's own queue, so both belong on a private serial queue.
/// What crosses back to the main actor is only ever a result — a label, a joint set, a
/// barcode string.
final class CameraEngine: NSObject, @unchecked Sendable {
    enum Mode {
        /// Frames are handed to the caller for Vision work.
        case frames
        /// AVFoundation reads the codes itself; no frames are delivered.
        case barcodes
    }

    /// Called on the capture queue with each delivered frame, at most one in flight.
    var onFrame: (@Sendable (FrameBox) -> Void)?
    /// Called on the capture queue for each code read.
    var onBarcode: (@Sendable (String) -> Void)?
    /// Called on the main actor if the session cannot be built.
    var onFailure: (@Sendable () -> Void)?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.aymbam.dawnbreak.camera")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var isConfigured = false
    /// One frame in flight at a time. Vision on a 60 fps stream would heat the phone and
    /// deliver no extra accuracy; dropping frames while busy is the whole strategy.
    private let processing = Locked(false)

    static func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start(position: AVCaptureDevice.Position, mode: Mode) {
        queue.async { [weak self] in
            guard let self else { return }
            if !isConfigured {
                guard configure(position: position, mode: mode) else {
                    if let onFailure { DispatchQueue.main.async(execute: onFailure) }
                    return
                }
                isConfigured = true
            }
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configure(position: AVCaptureDevice.Position, mode: Mode) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 1280x720 rather than the highest available: Vision downsamples anyway, and the
        // lower preset halves the thermal cost of a mission that may run for two minutes.
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return false }
        session.addInput(input)

        switch mode {
        case .frames:
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(videoOutput) else { return false }
            session.addOutput(videoOutput)

        case .barcodes:
            guard session.canAddOutput(metadataOutput) else { return false }
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
            // Every symbology a kitchen cupboard might carry, plus QR for anyone who wants
            // to stick a code on the bathroom mirror.
            let wanted: [AVMetadataObject.ObjectType] = [
                .ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .qr, .pdf417, .aztec, .dataMatrix
            ]
            metadataOutput.metadataObjectTypes = wanted.filter { metadataOutput.availableMetadataObjectTypes.contains($0) }
        }

        return true
    }
}

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let onFrame, !processing.value else { return }
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processing.value = true
        // The box hands the buffer off; this queue drops its reference immediately, and
        // `alwaysDiscardsLateVideoFrames` means the pool is never starved by the handoff.
        onFrame(FrameBox(buffer: buffer, orientation: .right) { [weak self] in
            self?.processing.value = false
        })
    }
}

extension CameraEngine: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let onBarcode else { return }
        for object in metadataObjects {
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let payload = code.stringValue, !payload.isEmpty else { continue }
            onBarcode(payload)
            return
        }
    }
}

/// Carries a pixel buffer from the capture queue to whoever is doing the Vision work.
///
/// `CVPixelBuffer` has no `Sendable` conformance and cannot get one, but this is a handoff
/// rather than sharing: the capture queue releases its reference as soon as the box is made,
/// and exactly one box is outstanding at a time. `finish()` is what lets the next frame
/// through, so forgetting to call it stalls the stream rather than corrupting anything.
struct FrameBox: @unchecked Sendable {
    let buffer: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
    private let release: @Sendable () -> Void

    init(buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, release: @escaping @Sendable () -> Void) {
        self.buffer = buffer
        self.orientation = orientation
        self.release = release
    }

    func finish() { release() }
}

/// A mutex around one value. Used for the in-flight flag, which is written on the capture
/// queue and read there too, but is also cleared from whichever context finished the work.
final class Locked<Value>: @unchecked Sendable {
    private var storage: Value
    private let lock = NSLock()

    init(_ value: Value) { storage = value }

    var value: Value {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}

/// The viewfinder. A `UIViewRepresentable` because `AVCaptureVideoPreviewLayer` is a layer,
/// and wrapping it is cheaper and sharper than drawing frames into a SwiftUI `Image`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var isMirrored = false

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
