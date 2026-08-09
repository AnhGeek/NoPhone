import SwiftUI
import FamilyControls

/// App shell.
///
/// A custom floating tab bar rather than `TabView`'s: the stock bar is a
/// translucent system chrome that would sit under this design like a foreign
/// object. This one is a sticker too — chunky outline, offset shadow, and a
/// candy lozenge that slides behind the selected tab.
struct RootView: View {
    @Environment(AppState.self) private var state
    @Environment(ScreenTimeService.self) private var screenTime
    @State private var tab: Tab = .home
    @State private var selectedAppID: UUID?
    @State private var showPicker = false
    /// The app a long press on the home strip is asking to untrack.
    @State private var pendingUntrack: TrackedApp?

    enum Tab: String, CaseIterable, Identifiable {
        case home, quests, lockScreen, profile

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home:       "Today"
            case .quests:     "Quests"
            case .lockScreen: "Lock"
            case .profile:    "You"
            }
        }

        var symbol: String {
            switch self {
            case .home:       "house.fill"
            case .quests:     "checklist"
            case .lockScreen: "lock.iphone"
            case .profile:    "person.fill"
            }
        }

        var tint: AppTint {
            switch self {
            case .home:       .grape
            case .quests:     .mint
            case .lockScreen: .sky
            case .profile:    .bubblegum
            }
        }
    }

    /// The tab bar writes through here rather than straight to `tab`.
    ///
    /// A pushed `AppDetailView` sits *above* the stack root, so swapping the
    /// root under it changes nothing on screen — the bar looks dead. Popping
    /// first makes every tap land on that tab's own screen, and because a
    /// binding setter runs even when the value is unchanged, re-tapping the
    /// current tab pops to root too.
    private var tabSelection: Binding<Tab> {
        Binding {
            tab
        } set: { newTab in
            selectedAppID = nil
            tab = newTab
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                Group {
                    switch tab {
                    case .home:
                        HomeView(selectedAppID: $selectedAppID,
                                 pendingUntrack: $pendingUntrack) {
                            withAnimation(Motion.jelly) { tab = .quests }
                        }
                    case .quests:     QuestsView()
                    case .lockScreen: LockScreenStudio()
                    case .profile:    SettingsView()
                    }
                }
                .navigationDestination(item: $selectedAppID) { id in
                    AppDetailView(appID: id)
                }
            }
            .tint(Theme.brand)
            TabBar(selection: tabSelection)
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xs)
        }
        .screenTimeSetup(isPresented: $showPicker)
        .overlay {
            // Nothing to show until real apps are picked. Covering the shell
            // is deliberate: a dashboard of zeroes would read as a bug, and
            // there is exactly one useful action here.
            if !state.hasTrackedApps {
                ScreenTimeGate { showPicker = true }
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
        // Above the tab bar, not inside the stack: untracking is a decision
        // about the whole app, and the bar must not stay tappable behind it.
        .overlay {
            if let app = pendingUntrack {
                ConfirmOverlay(
                    title: "Stop tracking \(app.name)?",
                    message: "Its budget, today's usage, and any earned time go away. The app stops being blocked.",
                    symbol: "trash.fill",
                    confirmTitle: "Stop tracking",
                    cancelTitle: "Keep it"
                ) {
                    withAnimation(Motion.jelly) { state.untrack(app.id) }
                    pendingUntrack = nil
                } onCancel: {
                    pendingUntrack = nil
                }
                .transition(.opacity)
                .zIndex(8)
            }
        }
        .animation(Motion.jelly, value: pendingUntrack)
        .sensoryFeedback(.impact(weight: .medium), trigger: pendingUntrack?.id)
        .overlay {
            if let celebration = state.pendingCelebration {
                CelebrationOverlay(celebration: celebration) {
                    withAnimation(Motion.jelly) { state.pendingCelebration = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(Motion.jelly, value: state.pendingCelebration)
        // A quest refill has to lift a shield *now*, not at the next launch —
        // otherwise the reward is invisible until the person quits the app.
        // Budget edits move the thresholds too, so both re-register.
        .onChange(of: state.apps) { _, apps in
            // Emptying the roster is the one case that *must* still run: a
            // shield lives in ManagedSettings, not in this app's memory, so an
            // app untracked while spent stays blocked forever if nothing
            // clears it. Returning early here left people locked out of an app
            // this app no longer knew about.
            guard !apps.isEmpty else {
                screenTime.stopMonitoring()
                return
            }
            screenTime.applyShields(for: apps)
            screenTime.startMonitoring(apps: apps)
        }
    }
}

/// The floating tab bar.
struct TabBar: View {
    @Binding var selection: RootView.Tab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootView.Tab.allCases) { tab in
                Button {
                    withAnimation(Motion.jelly) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .black))
                            .symbolEffect(.bounce, value: selection == tab)
                        Text(tab.title)
                            .font(Typo.micro)
                    }
                    .foregroundStyle(selection == tab ? tab.tint.contrastInk : Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xs + 2)
                    .background {
                        if selection == tab {
                            // One shared lozenge that slides between tabs —
                            // reads as a single physical object moving, not
                            // four independent highlights.
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(tab.tint.gradient)
                                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(Theme.outline, lineWidth: Stroke.thin))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Theme.outline, lineWidth: Stroke.medium)
        )
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Theme.shadowHard)
                .offset(y: 5)
        )
        .shadow(color: Palette.ink.opacity(0.18), radius: 20, y: 8)
    }
}

#Preview("Root") {
    RootView()
        .environment(AppState.preview)
        .environment(ScreenTimeService())
}

// MARK: - Setup presentation

/// Presents Screen Time's picker and, once something is chosen, the setup
/// screen — as **siblings**, never nested.
///
/// `familyActivityPicker` presented from inside a `fullScreenCover` collapses
/// the outer presentation on iPad, dumping the user back to the gate. Keeping
/// both at the same level is the fix.
private struct SetupPresenter: ViewModifier {
    @Binding var isPresented: Bool
    @State private var selection = FamilyActivitySelection()
    @State private var showSetup = false

    func body(content: Content) -> some View {
        content
            .familyActivityPicker(isPresented: $isPresented, selection: $selection)
            .onChange(of: isPresented) { _, open in
                guard !open else { return }
                let apps = selection.applicationTokens.count
                let cats = selection.categoryTokens.count
                DiagLog.write("host: picker closed apps=\(apps) categories=\(cats)")
                if apps + cats > 0 { showSetup = true }
            }
            .fullScreenCover(isPresented: $showSetup) {
                BudgetSetupView(selection: selection) {
                    // Close setup first, then reopen the picker on the next
                    // runloop — presenting one over the other is the bug.
                    showSetup = false
                    DispatchQueue.main.async { isPresented = true }
                }
            }
    }
}

extension View {
    func screenTimeSetup(isPresented: Binding<Bool>) -> some View {
        modifier(SetupPresenter(isPresented: isPresented))
    }
}
