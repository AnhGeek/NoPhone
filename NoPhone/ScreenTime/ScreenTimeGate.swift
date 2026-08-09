import SwiftUI

/// What the app is before it has any real data: a permission ask, then a
/// picker. Shown whenever the roster is empty.
///
/// Each authorization state gets its own copy, because they need genuinely
/// different actions — and because "Screen Time is unavailable in the
/// Simulator" is a developer condition that must never be dressed up as the
/// person having refused something.
struct ScreenTimeGate: View {
    @Environment(ScreenTimeService.self) private var screenTime
    @Environment(AppState.self) private var state
    #if targetEnvironment(simulator)
    @Environment(SimulatorUsageDriver.self) private var driver
    #endif
    var onPick: () -> Void

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Mascot(mood: .happy, tint: .grape, size: 130)

                VStack(spacing: Space.xs) {
                    Text(title)
                        .font(Typo.title)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(Typo.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                action
            }
            .padding(.horizontal, Space.xl)
        }
        .task { screenTime.refreshAuthorization() }
    }

    private var title: String {
        switch screenTime.authorization {
        case .approved:       "Pick your apps"
        case .denied:         "Screen Time is off"
        case .unavailable:    "Not available here"
        case .unknown:        "Let's set you up"
        }
    }

    private var message: String {
        switch screenTime.authorization {
        case .approved:
            "Choose the apps you want on a budget. Each one gets a bar that starts full and drains as you use it."
        case .denied:
            "NoPhone needs Screen Time access to see how long apps are open. You can turn it back on in Settings."
        case .unavailable(let reason):
            reason
        case .unknown:
            "NoPhone uses Apple's Screen Time to measure app use. Nothing leaves your device — we never learn which apps you picked."
        }
    }

    @ViewBuilder
    private var action: some View {
        switch screenTime.authorization {
        case .approved:
            JellyButton(title: "Choose apps", symbol: "apps.iphone", tint: .mint, fullWidth: true,
                        action: onPick)
        case .unknown:
            JellyButton(title: "Allow Screen Time", symbol: "hand.raised.fill", tint: .grape, fullWidth: true) {
                Task { await screenTime.requestAuthorization() }
            }
        case .denied:
            JellyButton(title: "Open Settings", symbol: "gear", tint: .sky, fullWidth: true) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        case .unavailable:
            #if targetEnvironment(simulator)
            VStack(spacing: Space.sm) {
                JellyButton(title: "Load demo apps", symbol: "wand.and.stars",
                            tint: .tangerine, fullWidth: true) {
                    driver.seedApps(into: state)
                }
                Text("Development only. Fills the roster with fixtures and drives them through the real usage pipeline.")
                    .font(Typo.micro)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            #else
            EmptyNote(symbol: "iphone.slash", text: "Run on a physical device to try this.")
            #endif
        }
    }
}

#Preview("Gate") {
    ScreenTimeGate {}
        .environment(AppState.preview)
        .environment(ScreenTimeService())
        #if targetEnvironment(simulator)
        .environment(SimulatorUsageDriver())
        #endif
}
