import AVFoundation
import DawnbreakKit
import SwiftUI

/// Registers the thing the photo or barcode mission will ask for.
///
/// Done at setup time, in daylight, deliberately: asking someone at 06:00 to photograph an
/// object they never registered is a mission with no answer. The screen also proves the
/// object is recognisable *before* the alarm depends on it, which is the difference between a
/// mission and a trap.
struct EnrollmentView: View {
    @Environment(\.dismiss) private var dismiss
    let mission: MissionKind
    let onDone: (MissionConfig.Enrollment) -> Void

    @State private var recogniser = ObjectRecogniser()
    @State private var reader = BarcodeReader()
    @State private var capturedReference: String?
    @State private var displayName = ""
    @State private var holdProgress: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(key: mission == .photo ? "enroll.photo.explainer" : "enroll.barcode.explainer")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                if permission == .granted {
                    viewfinder
                } else if permission == .unknown {
                    ProgressView().tint(Theme.accent).frame(maxHeight: .infinity)
                } else {
                    deniedCard
                }

                if capturedReference != nil {
                    nameField
                }

                Spacer(minLength: 0)

                Button {
                    guard let reference = capturedReference else { return }
                    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onDone(MissionConfig.Enrollment(
                        reference: reference,
                        displayName: trimmed.isEmpty ? fallbackName(for: reference) : trimmed
                    ))
                    dismiss()
                } label: {
                    Text("enroll.save", bundle: .main)
                }
                .buttonStyle(DawnButtonStyle(isEnabled: capturedReference != nil))
                .disabled(capturedReference == nil)
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.bottom, 20)
            }
            .dawnCanvas()
            .navigationTitle(Text(key: mission == .photo ? "enroll.photo.title" : "enroll.barcode.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Text("action.cancel", bundle: .main) }
                }
            }
            .task {
                if mission == .photo {
                    await recogniser.start(position: .back)
                } else {
                    await reader.start()
                }
            }
            .onDisappear {
                recogniser.stop()
                reader.stop()
            }
            .onChange(of: reader.lastPayload) { _, payload in
                guard mission == .barcode, let payload else { return }
                capturedReference = payload
                reader.stop()
            }
        }
    }

    private var permission: ObjectRecogniser.Permission {
        mission == .photo ? recogniser.permission : reader.permission
    }

    @ViewBuilder private var viewfinder: some View {
        ZStack {
            CameraPreview(session: mission == .photo ? recogniser.engine.session : reader.engine.session)
                .clipShape(.rect(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.hairline))

            if mission == .barcode {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.accent, lineWidth: 3)
                    .frame(width: 230, height: 140)
            }

            VStack {
                Spacer()
                if mission == .photo {
                    photoStatus
                } else if capturedReference != nil {
                    badge(systemImage: "checkmark.circle.fill", text: localized("enroll.barcode.captured"), tint: Theme.success)
                }
            }
            .padding(.bottom, 14)
        }
        .frame(maxHeight: 380)
        .padding(.horizontal, Theme.Metric.gutter)
    }

    @ViewBuilder private var photoStatus: some View {
        if let best = recogniser.bestLabel, best.confidence > 0.2 {
            VStack(spacing: 8) {
                badge(
                    systemImage: "sparkle.magnifyingglass",
                    text: localized("enroll.photo.seeing", best.label),
                    tint: Theme.accent
                )
                Button {
                    capturedReference = best.label
                    if displayName.isEmpty { displayName = best.label }
                    recogniser.stop()
                } label: {
                    Text("enroll.photo.useThis", bundle: .main)
                        .font(Theme.captionFont)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.dawnGradient, in: .capsule)
                        .foregroundStyle(.white)
                }
            }
        } else {
            badge(systemImage: "viewfinder", text: localized("enroll.photo.searching"), tint: Theme.textSecondary)
        }
    }

    private func badge(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(Theme.captionFont)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(tint.opacity(0.9), in: .capsule)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(titleKey: "enroll.name")
            TextField(text: $displayName) {
                Text("enroll.name.placeholder", bundle: .main)
            }
            .font(Theme.bodyFont)
            .padding(12)
            .background(Theme.surface, in: .rect(cornerRadius: 12))
            .submitLabel(.done)
            Text("enroll.name.hint", bundle: .main)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, Theme.Metric.gutter)
    }

    private var deniedCard: some View {
        MissionUnavailableView(
            titleKey: "mission.camera.denied.title",
            bodyKey: "enroll.camera.denied.body",
            onOverride: { dismiss() }
        )
        .frame(maxHeight: .infinity)
    }

    /// A name for the object when the user does not type one. The classifier's English label
    /// is a poor display name, so a barcode falls back to a generic noun rather than showing
    /// a fourteen-digit number in the alarm row.
    private func fallbackName(for reference: String) -> String {
        mission == .barcode ? localized("enroll.barcode.defaultName") : reference
    }
}
