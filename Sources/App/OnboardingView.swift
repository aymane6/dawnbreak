import DawnbreakKit
import SwiftUI

/// Four pages: the promise, how missions work, the permission, and the first alarm.
///
/// The permission page is third rather than first deliberately. Asking for the one
/// irreversible grant before the user knows what the app does is how an alarm app ends up
/// permanently unable to ring.
struct OnboardingView: View {
    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var isRequesting = false

    private static let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                promisePage.tag(0)
                missionsPage.tag(1)
                permissionPage.tag(2)
                firstAlarmPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)

            dots
            footer
        }
        .dawnCanvas()
        .interactiveDismissDisabled()
        .task { app.bridge.observeAuthorization() }
    }

    // MARK: - Pages

    private var promisePage: some View {
        OnboardingPage(
            systemImage: "sunrise.fill",
            titleKey: "onboarding.promise.title",
            bodyKey: "onboarding.promise.body"
        ) {
            VStack(spacing: 10) {
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
                if app.bridge.authorization == .authorized {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("onboarding.permission.granted", bundle: .main)
                    }
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.success)
                } else {
                    Button {
                        Task {
                            isRequesting = true
                            await app.bridge.requestAuthorization()
                            isRequesting = false
                            if app.bridge.authorization == .authorized { page = 3 }
                        }
                    } label: {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("onboarding.permission.allow", bundle: .main)
                        }
                    }
                    .buttonStyle(DawnButtonStyle())
                    .disabled(isRequesting)

                    if app.bridge.authorization == .denied {
                        Text("onboarding.permission.denied", bundle: .main)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.warning)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                BulletRow(systemImage: "1.circle.fill", titleKey: "onboarding.first.step1")
                BulletRow(systemImage: "2.circle.fill", titleKey: "onboarding.first.step2")
                BulletRow(systemImage: "3.circle.fill", titleKey: "onboarding.first.step3")
            }
        }
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
        VStack(spacing: 10) {
            Button {
                if page < Self.pageCount - 1 {
                    page += 1
                } else {
                    finish()
                }
            } label: {
                Text(page < Self.pageCount - 1 ? "onboarding.next" : "onboarding.start", bundle: .main)
            }
            .buttonStyle(DawnButtonStyle())
            .accessibilityIdentifier(AccessibilityID.onboardingNext)

            Button {
                finish()
            } label: {
                Text("onboarding.skip", bundle: .main)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textTertiary)
            }
            .opacity(page < Self.pageCount - 1 ? 1 : 0)
            .disabled(page == Self.pageCount - 1)
        }
        .padding(.horizontal, Theme.Metric.gutter)
        .padding(.bottom, 24)
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

private struct BulletRow: View {
    let systemImage: String
    let titleKey: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(key: titleKey)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
