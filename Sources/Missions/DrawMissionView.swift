import DawnbreakKit
import SwiftUI
import UIKit
import Vision

/// Draw the named thing, and let the on-device classifier decide.
///
/// The prompt shown is a localized noun; the label matched is the English one the classifier
/// emits. Conflating the two is how a French user is told to draw "bateau" and then fails
/// because Vision said "boat".
struct DrawMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var prompt: DrawingPrompt
    @State private var strokes: [Stroke] = []
    @State private var current: Stroke?
    @State private var isChecking = false
    @State private var verdict: Verdict?

    private enum Verdict: Equatable { case tooEmpty, notRecognised(String?) }

    struct Stroke: Equatable {
        var points: [CGPoint]
    }

    init(config: MissionConfig, callbacks: MissionCallbacks) {
        self.config = config
        self.callbacks = callbacks
        var generator = SystemRandomNumberGenerator()
        _prompt = State(initialValue: DrawingPrompt.random(using: &generator))
    }

    var body: some View {
        MissionScaffold(
            instructionKey: MissionKind.draw.instructionKey,
            instruction: localized("mission.draw.prompt", localized(prompt.nameKey).uppercased())
        ) {
            VStack(spacing: 10) {
                canvas
                if let verdict {
                    verdictLine(verdict)
                }
            }
        } control: {
            HStack(spacing: 10) {
                Button {
                    strokes = []
                    current = nil
                    verdict = nil
                } label: {
                    Text("mission.draw.clear", bundle: .main)
                }
                .buttonStyle(QuietButtonStyle())
                .frame(maxWidth: 130)

                Button {
                    Task { await check() }
                } label: {
                    if isChecking {
                        ProgressView().tint(.white)
                    } else {
                        Text("mission.draw.check", bundle: .main)
                    }
                }
                .buttonStyle(DawnButtonStyle())
                .disabled(isChecking || strokes.isEmpty)
            }
        }
    }

    private var canvas: some View {
        // White, because the classifier is trained on photographs and drawings on paper.
        // A dark canvas with light strokes scores far worse for the same drawing.
        Canvas { context, _ in
            for stroke in strokes + [current].compactMap({ $0 }) {
                guard stroke.points.count > 1 else { continue }
                var path = Path()
                path.move(to: stroke.points[0])
                for point in stroke.points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
        }
        .background(.white)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, Theme.Metric.gutter)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    verdict = nil
                    if current == nil { current = Stroke(points: [value.location]) }
                    else { current?.points.append(value.location) }
                }
                .onEnded { _ in
                    if let current, current.points.count > 1 { strokes.append(current) }
                    self.current = nil
                }
        )
        .accessibilityLabel(Text("mission.draw.canvas", bundle: .main))
    }

    @ViewBuilder private func verdictLine(_ verdict: Verdict) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
            switch verdict {
            case .tooEmpty:
                Text("mission.draw.tooEmpty", bundle: .main)
            case .notRecognised(let guess):
                if let guess {
                    Text(localized("mission.draw.sawInstead", guess))
                } else {
                    Text("mission.draw.notRecognised", bundle: .main)
                }
            }
        }
        .font(Theme.captionFont)
        .foregroundStyle(Theme.warning)
        .multilineTextAlignment(.center)
    }

    private func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        // Ink coverage first: an almost-empty canvas classifies as "paper" with high
        // confidence, and telling the user "that is not a boat" would be misleading.
        guard totalInkLength > 260 else {
            verdict = .tooEmpty
            return
        }

        guard let image = render() else {
            verdict = .notRecognised(nil)
            return
        }

        let request = ClassifyImageRequest()
        guard let observations = try? await request.perform(on: image, orientation: .up) else {
            verdict = .notRecognised(nil)
            return
        }
        let ranked = observations
            .sorted { $0.confidence > $1.confidence }
            .map { (label: $0.identifier, confidence: $0.confidence) }

        if prompt.matches(observations: ranked, threshold: config.recognitionThreshold) {
            callbacks.cleared()
        } else {
            verdict = .notRecognised(ranked.first(where: { $0.confidence > 0.2 })?.label)
        }
    }

    /// Total stroke length in points, as a proxy for "did they actually draw something".
    private var totalInkLength: CGFloat {
        strokes.reduce(0) { total, stroke in
            total + zip(stroke.points, stroke.points.dropFirst()).reduce(0) { sum, pair in
                sum + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
            }
        }
    }

    /// Renders the strokes into a 360pt square white image for the classifier.
    ///
    /// Drawn from the model rather than snapshotting the view: an `ImageRenderer` over the
    /// live canvas would capture the rounded corners and the border, and a black frame around
    /// every drawing shifts every classification.
    private func render() -> CGImage? {
        let side: CGFloat = 360
        let bounds = drawingBounds()
        guard bounds.width > 1, bounds.height > 1 else { return nil }

        // Fit the drawing into the square with a margin, so a small sketch in one corner is
        // classified as well as one that fills the canvas.
        let margin: CGFloat = 30
        let scale = min((side - 2 * margin) / bounds.width, (side - 2 * margin) / bounds.height)
        let offset = CGPoint(
            x: (side - bounds.width * scale) / 2 - bounds.minX * scale,
            y: (side - bounds.height * scale) / 2 - bounds.minY * scale
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor.black.setStroke()
            let path = UIBezierPath()
            path.lineWidth = 9
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            for stroke in strokes where stroke.points.count > 1 {
                let mapped = stroke.points.map {
                    CGPoint(x: $0.x * scale + offset.x, y: $0.y * scale + offset.y)
                }
                path.move(to: mapped[0])
                for point in mapped.dropFirst() { path.addLine(to: point) }
            }
            path.stroke()
        }
        return image.cgImage
    }

    private func drawingBounds() -> CGRect {
        let points = strokes.flatMap(\.points)
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
