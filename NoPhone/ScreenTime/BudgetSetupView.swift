import SwiftUI
import FamilyControls
import ManagedSettings

/// Turning opaque `ApplicationToken`s into `TrackedApp`s.
///
/// Screen Time hands back tokens with no name, no icon, and no bundle ID. That
/// is a hard privacy boundary, not an oversight — so the person names each app
/// themselves, and we assign our own glyph and tint. The upside is that the
/// whole design system keeps working: real tracking, our ink outlines.
/// Step 2 of setup: name each picked target and set its allowance.
///
/// **It does not present the system picker.** That is the whole point of this
/// split: `familyActivityPicker` presented from inside a `fullScreenCover`
/// tears the outer presentation down with it on iPad, which dropped the user
/// straight back to the permission gate. The owner presents the picker; this
/// view only ever receives the result.
struct BudgetSetupView: View {
    @Environment(AppState.self) private var state
    @Environment(ScreenTimeService.self) private var screenTime
    @Environment(\.dismiss) private var dismiss

    /// What the system picker returned.
    let selection: FamilyActivitySelection
    /// Ask the owner to reopen the picker — again, never presented here.
    var onChangeSelection: () -> Void

    @State private var drafts: [Draft] = []

    var body: some View {
        NavigationStack {
            Group {
                if drafts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Space.lg) {
                            ForEach($drafts) { $draft in
                                DraftCard(draft: $draft)
                            }
                            GhostButton(title: "Add or change selection", symbol: "plus.circle") {
                                DiagLog.write("setup: change selection tapped")
                                onChangeSelection()
                            }
                        }
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, Space.md)
                    }
                }
            }
            .playgroundBackground()
            .navigationTitle("Set the limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Pinned, never scrolled: at the bottom of a ScrollView this button
            // could sit below the fold, which is indistinguishable from broken.
            .safeAreaInset(edge: .bottom) { actionBar }
            .task { buildDrafts() }
            .onChange(of: selection) { _, _ in buildDrafts() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Mascot(mood: .chill, tint: .sky, size: 110)
            Text("Nothing selected yet")
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Tick a single app, or a whole category, and it'll show up here with its own bar.")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space.xl)
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: Space.xs) {
            if drafts.isEmpty {
                JellyButton(title: "Choose apps", symbol: "apps.iphone",
                            tint: .grape, fullWidth: true) {
                    onChangeSelection()
                }
            } else {
                JellyButton(title: startTitle,
                            symbol: "checkmark",
                            tint: .mint,
                            fullWidth: true) {
                    DiagLog.write("ui: Start tracking TAPPED")
                    commit()
                }
                .onAppear { DiagLog.write("ui: Start tracking rendered") }

                if unnamedCount > 0 {
                    Text(defaultNameNote)
                        .font(Typo.micro)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xs)
        .background(.ultraThinMaterial)
    }

    // MARK: - Derived

    /// Naming is encouraged, not required — a blank name used to block the
    /// button entirely, turning a fiddly keyboard into a dead end.
    private func resolvedName(for draft: Draft, at index: Int) -> String {
        let typed = draft.name.trimmingCharacters(in: .whitespaces)
        guard typed.isEmpty else { return typed }
        return draft.target.isCategory ? "Category \(index + 1)" : "App \(index + 1)"
    }

    private var unnamedCount: Int {
        drafts.filter { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    // Plain strings, not `^[...](inflect:)` markup: `JellyButton.title` is a
    // `String`, so it reaches `Text(verbatim:)` and the markup would render
    // literally on screen instead of being pluralised.
    private var startTitle: String {
        drafts.count == 1 ? "Start tracking 1 budget"
                          : "Start tracking \(drafts.count) budgets"
    }

    private var defaultNameNote: String {
        unnamedCount == 1 ? "1 budget will get a default name."
                          : "\(unnamedCount) budgets will get a default name."
    }

    // MARK: - Actions

    /// Preserves anything already typed, so reopening the picker to add one
    /// target does not wipe the names on the others.
    private func buildDrafts() {
        let targets: [TrackedTarget] =
            selection.applicationTokens.compactMap { TrackedApp.encode($0).map(TrackedTarget.application) }
            + selection.categoryTokens.compactMap { TrackedApp.encode($0).map(TrackedTarget.category) }

        guard targets != drafts.map(\.target) else {
            DiagLog.write("setup: buildDrafts no-op (\(targets.count) unchanged)")
            return
        }

        drafts = targets.map { target in
            drafts.first { $0.target == target } ?? Draft(target: target)
        }
        DiagLog.write("setup: \(drafts.count) draft(s) from apps=\(selection.applicationTokens.count) categories=\(selection.categoryTokens.count)")
    }

    private func commit() {
        DiagLog.write("setup: commit \(drafts.count) draft(s)")
        for (index, draft) in drafts.enumerated() {
            state.track(name: resolvedName(for: draft, at: index),
                        target: draft.target,
                        category: draft.category,
                        budgetMinutes: draft.budgetMinutes)
        }
        screenTime.startMonitoring(apps: state.apps)
        screenTime.applyShields(for: state.apps)
        DiagLog.write("setup: committed, state.apps=\(state.apps.count)")
        dismiss()
    }
}

#Preview("Budget setup") {
    BudgetSetupView(selection: FamilyActivitySelection()) {}
        .environment(AppState.preview)
        .environment(ScreenTimeService())
}


/// One draft's editor.
///
/// A separate view, not an inline builder, so typing a name invalidates only
/// this card — and, crucially, only the parts of it that changed.
private struct DraftCard: View {
    @Binding var draft: Draft

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            TargetLabel(target: draft.target).equatable()

            TextField("Name it", text: $draft.name)
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(Space.sm)
                // `surfaceSunk`, not `surface` — the card is already `surface`,
                // so matching it would leave the field with no edge at all.
                .background(
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(Theme.surfaceSunk)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                                .strokeBorder(Theme.outline, lineWidth: Stroke.thin)
                        )
                )

            Picker("Category", selection: $draft.category) {
                ForEach(AppCategory.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Theme.textPrimary)

            HStack {
                Text("Daily allowance")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(Fmt.short(draft.budgetMinutes * 60))
                    .font(Typo.timer(17))
                    .foregroundStyle(Theme.textPrimary)
            }
            Slider(value: $draft.budgetMinutes, in: 5...240, step: 5)
                .tint(Theme.brand)
        }
        .padding(Space.md)
        .cardSurface(radius: Radius.lg, shadow: .card)
    }
}

/// Apple's `Label` for a token — the only way to show what was actually
/// picked. It appears here, during naming, and nowhere else in the product.
///
/// `Equatable` is load-bearing, not an optimisation. `Label(token)` is a
/// UIKit-backed view; re-rendering it on every keystroke makes it detach and
/// re-attach ("Label is already or no longer part of the view hierarchy"),
/// which drops the text field's first responder and closes the keyboard
/// mid-word. Comparing on the token alone means a name change never touches it.
private struct TargetLabel: View, Equatable {
    let target: TrackedTarget

    static func == (lhs: TargetLabel, rhs: TargetLabel) -> Bool {
        lhs.target == rhs.target
    }

    var body: some View {
        switch target {
        case .application(let data):
            if let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
                Label(token).labelStyle(.titleAndIcon).font(Typo.body)
            }
        case .category(let data):
            if let token = try? JSONDecoder().decode(ActivityCategoryToken.self, from: data) {
                HStack(spacing: Space.xs) {
                    Label(token).labelStyle(.titleAndIcon).font(Typo.body)
                    Chip(text: "Whole category", symbol: "square.grid.2x2", tint: .sky)
                }
            }
        }
    }
}

/// One picked target — an app or a category — awaiting a name and a budget.
struct Draft: Identifiable {
    let id = UUID()
    let target: TrackedTarget
    var name: String = ""
    var category: AppCategory = .social
    var budgetMinutes: Double = 60
}
