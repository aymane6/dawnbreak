import DawnbreakKit
import SwiftUI

/// Four pages: the promise, how missions work, the permission, and the first alarm.
///
/// The permission page is third rather than first deliberately. Asking for the one
/// irreversible grant before the user knows what the app does is how an alarm app ends up
/// permanently unable to ring.
///
/// App Review rejected build 11 under 5.1.1(iv) for the shape of that page: its button said
/// "Allow alarms", and a Skip let the user close it without the system ever asking. A message
/// before a permission alert may explain and must not steer, so the page now has exactly one way
/// forward, labelled Continue, and it always ends in the system alert. There is no Skip on any
/// page and no swiping between them, because a swipe past the explanation is the same delay.
struct OnboardingView: View {
    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var isRequesting = false
    /// The last button says "Set my first alarm", so it opens the editor over this page, and
    /// onboarding ends when the editor closes, saved or not. It used to end on an empty list,
    /// one tap short of what the button had just promised.
    @State private var composing = false

    private static let pageCount = 4
    private static let permissionPageIndex = 2

    var body: some View {
        VStack(spacing: 0) {
            // A ZStack, so the outgoing and incoming pages overlap while they slide instead of
            // being stacked one above the other for the length of the animation.
            ZStack {
                currentPage
                    .id(page)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            dots
            footer
        }
        .dawnCanvas()
        .interactiveDismissDisabled()
        .task { app.bridge.observeAuthorization() }
        .sheet(isPresented: $composing, onDismiss: finish) {
            AlarmEditorView(alarm: AlarmDraft(), isNew: true)
        }
    }

    @ViewBuilder private var currentPage: some View {
        switch page {
        case 0: promisePage
        case 1: missionsPage
        case Self.permissionPageIndex: permissionPage.accessibilityIdentifier(AccessibilityID.onboardingPermission)
        default: firstAlarmPage
        }
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Pages

    private var promisePage: some View {
        OnboardingPage(
            systemImage: "sunrise.fill",
            titleKey: "onboarding.promise.title",
            bodyKey: "onboarding.promise.body"
        ) {
            BulletList {
                BulletRow(systemImage: "speaker.wave.3.fill", titleKey: "onboarding.promise.silent")
                BulletRow(systemImage: "moon.zzz.fill", titleKey: "onboarding.promise.focus")
                BulletRow(systemImage: "lock.iphone", titleKey: "onboarding.promise.locked")
            }
        }
    }

    private var missionsPage: some View {
        OnboardingPage(
            systemImage: "checklist",
            titleKey: "onboarding.missions.title",
            bodyKey: "onboarding.missions.body"
        ) {
            // A sample of the twelve, in effort order, so the page shows range without
            // becoming a grid of twelve icons nobody reads.
            let sample: [MissionKind] = [.math, .shake, .memory, .typing, .steps, .photo, .draw, .squats]
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 10), count: 4), spacing: 10) {
                ForEach(sample, id: \.self) { kind in
                    VStack(spacing: 6) {
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accent)
                        Text(key: kind.titleKey)
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: .rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var permissionPage: some View {
        OnboardingPage(
            systemImage: "bell.badge.fill",
            titleKey: "onboarding.permission.title",
            bodyKey: "onboarding.permission.body"
        ) {
            VStack(spacing: 12) {
                // Only the answer already given, if there is one. The way forward is the footer's
                // Continue, which is the one control on this page.
                switch app.bridge.authorization {
                case .authorized: grantedNote
                case .denied: deniedNote
                default: EmptyView()
                }

                Text("onboarding.permission.privacy", bundle: .main)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var firstAlarmPage: some View {
        OnboardingPage(
            systemImage: "alarm.waves.left.and.right.fill",
            titleKey: "onboarding.first.title",
            bodyKey: "onboarding.first.body"
        ) {
            VStack(spacing: 8) {
                BulletList {
                    BulletRow(systemImage: "1.circle.fill", titleKey: "onboarding.first.step1")
                    BulletRow(systemImage: "2.circle.fill", titleKey: "onboarding.first.step2")
                    BulletRow(systemImage: "3.circle.fill", titleKey: "onboarding.first.step3")
                }

                // A refusal is respected, and said once where it matters: nothing set from here
                // on will ring, and this is the way back if that was not the intent.
                if app.bridge.authorization == .denied {
                    deniedNote.padding(.top, 10)
                    Button(action: handleOpenSettings) {
                        Text("action.openSettings", bundle: .main)
                            .font(Theme.captionFont)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.warning)
                }
            }
        }
    }

    private var grantedNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("onboarding.permission.granted", bundle: .main)
        }
        .font(Theme.headlineFont)
        .foregroundStyle(Theme.success)
    }

    private var deniedNote: some View {
        Text("onboarding.permission.denied", bundle: .main)
            .font(Theme.captionFont)
            .foregroundStyle(Theme.warning)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Chrome

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<Self.pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.accent : Theme.hairline)
                    .frame(width: index == page ? 20 : 7, height: 7)
                    .animation(.spring(duration: 0.3), value: page)
            }
        }
        .padding(.bottom, 18)
        .accessibilityHidden(true)
    }

    private var footer: some View {
        Button(action: handleAdvance) {
            if isRequesting {
                ProgressView().tint(.white)
            } else {
                Text(key: footerKey)
            }
        }
        .buttonStyle(DawnButtonStyle())
        .disabled(isRequesting)
        .accessibilityIdentifier(AccessibilityID.onboardingNext)
        .padding(.horizontal, Theme.Metric.gutter)
        .padding(.bottom, 24)
    }

    /// "Continue" on the permission page, in the words App Review asked for: the button leads to
    /// the system's question and must not pre-empt its answer.
    private var footerKey: String {
        switch page {
        case Self.permissionPageIndex: "onboarding.continue"
        case Self.pageCount - 1: "onboarding.start"
        default: "onboarding.next"
        }
    }

    private func handleAdvance() {
        if page == Self.permissionPageIndex {
            Task { await requestThenAdvance() }
            return
        }
        guard page < Self.pageCount - 1 else {
            composing = true
            return
        }
        advance()
    }

    /// The alert is always shown if iOS has not had an answer yet, and onboarding moves on
    /// whatever the answer is. An answer given earlier is not asked again.
    private func requestThenAdvance() async {
        if app.bridge.authorization == .notDetermined {
            isRequesting = true
            await app.bridge.requestAuthorization()
            isRequesting = false
        }
        advance()
    }

    private func advance() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page += 1 }
        // The page is replaced rather than scrolled, so VoiceOver is told to start over on it.
        AccessibilityNotification.ScreenChanged().post()
    }

    private func handleOpenSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func finish() {
        app.preferences.hasCompletedOnboarding = true
        dismiss()
    }
}

private struct OnboardingPage<Extra: View>: View {
    let systemImage: String
    let titleKey: String
    let bodyKey: String
    @ViewBuilder let extra: Extra

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.dawnGradient)
                        .frame(width: 92, height: 92)
                        .blur(radius: 26)
                        .opacity(0.65)
                    Image(systemName: systemImage)
                        .font(.system(size: 50))
                        .foregroundStyle(Theme.dawnGradient)
                }
                .padding(.top, 44)

                Text(key: titleKey)
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(key: bodyKey)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                extra
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// A page's list, on a card of its own. Loose under a centred title, the left-aligned rows read
/// as text that had lost its alignment; on a panel they read as a list.
private struct BulletList<Rows: View>: View {
    @ViewBuilder let rows: Rows

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                rows
            }
        }
        .padding(.top, 4)
    }
}

private struct BulletRow: View {
    let systemImage: String
    let titleKey: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.14), in: .circle)
            Text(key: titleKey)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
