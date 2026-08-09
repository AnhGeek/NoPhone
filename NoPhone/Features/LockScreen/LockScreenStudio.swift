import SwiftUI

/// The Lock Screen studio.
///
/// A live, to-scale mock of the person's own Lock Screen with their real
/// numbers in it, plus the four styles to switch between and controls for
/// which apps appear. Showing the result in situ — under a wallpaper, beside
/// the clock, at real widget size — is the only honest way to choose; a list
/// of style names would be a guess.
struct LockScreenStudio: View {
    @Environment(AppState.self) private var state
    @State private var wallpaper: WallpaperPreset = .sunrise

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                header
                phone
                wallpaperPicker
                stylePicker
                pinnedApps
                explainer
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .playgroundBackground(tints: [.sky, .grape, .bubblegum])
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lock Screen")
                    .eyebrow()
                    .foregroundStyle(Theme.textTertiary)
                Text("Your time, front and center")
                    .font(Typo.title)
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
    }

    // MARK: - Phone mock

    private var phone: some View {
        PhoneFrame(wallpaper: wallpaper) {
            LockScreenContent(snapshot: state.lockScreenSnapshot)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pickers

    private var wallpaperPicker: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Preview on", title: "Wallpaper", symbol: "photo.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(WallpaperPreset.allCases) { preset in
                        Button {
                            withAnimation(Motion.jelly) { wallpaper = preset }
                        } label: {
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(preset.gradient)
                                .frame(width: 54, height: 76)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                        .strokeBorder(wallpaper == preset ? Theme.brand : Theme.outline,
                                                      lineWidth: wallpaper == preset ? Stroke.thick : Stroke.thin)
                                )
                                .overlay(alignment: .bottom) {
                                    Text(preset.title)
                                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.bottom, 4)
                                }
                        }
                        .buttonStyle(.plain)
                        .jellyPress()
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Pick one", title: "Widget style", symbol: "square.on.square.dashed")

            ForEach(LockScreenStyle.allCases) { style in
                StyleOptionRow(style: style,
                               selected: state.lockScreenStyle == style,
                               snapshot: snapshot(for: style)) {
                    withAnimation(Motion.jelly) { state.lockScreenStyle = style }
                }
            }
        }
    }

    private func snapshot(for style: LockScreenStyle) -> LockScreenSnapshot {
        var snapshot = state.lockScreenSnapshot
        snapshot.style = style
        snapshot.items = Array(snapshot.items.prefix(style.appCapacity))
        return snapshot
    }

    // MARK: - Pinned apps

    private var pinnedApps: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Shown on the Lock Screen",
                          title: "Pinned apps",
                          symbol: "pin.fill") {
                Chip(text: "\(state.lockScreenApps.count)/\(state.lockScreenStyle.appCapacity) fit",
                     tint: .sky)
            }

            VStack(spacing: 0) {
                ForEach(state.apps) { app in
                    Button {
                        withAnimation(Motion.jelly) { state.togglePin(app.id) }
                    } label: {
                        HStack(spacing: Space.sm) {
                            AppGlyph(symbol: app.symbol, tint: app.tint, size: 36,
                                     dimmed: !app.pinnedToLockScreen)
                            Text(app.name)
                                .font(Typo.body)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: app.pinnedToLockScreen
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(app.pinnedToLockScreen
                                                 ? app.tint.base : Theme.textTertiary)
                        }
                        .padding(.vertical, Space.xs)
                    }
                    .buttonStyle(.plain)

                    if app.id != state.apps.last?.id {
                        Divider().overlay(Theme.outlineSoft)
                    }
                }
            }
            .padding(Space.sm)
            .cardSurface()

            Text("Only the first \(state.lockScreenStyle.appCapacity) fit in \(state.lockScreenStyle.title). The rest still count toward your total.")
                .font(Typo.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "How to add it", title: "Three taps", symbol: "hand.point.up.left.fill")
            VStack(alignment: .leading, spacing: Space.sm) {
                StepRow(number: 1, text: "Touch and hold your Lock Screen, then tap Customize.")
                StepRow(number: 2, text: "Tap the area under the clock to add widgets.")
                StepRow(number: 3, text: "Pick NoPhone, then choose this style.")
            }
            .padding(Space.md)
            .cardSurface()
        }
    }
}

// MARK: - Style option row

/// A style choice shown as its own live widget rather than a name — you pick
/// the thing you're looking at.
struct StyleOptionRow: View {
    let style: LockScreenStyle
    let selected: Bool
    let snapshot: LockScreenSnapshot
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.md) {
                LockScreenRectangularView(snapshot: snapshot)
                    .frame(width: 150, height: 68)
                    .padding(Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(Theme.surfaceSunk)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .strokeBorder(Theme.outlineSoft, lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: style.symbol)
                            .font(.system(size: 12, weight: .black))
                        Text(style.title)
                            .font(Typo.body)
                    }
                    .foregroundStyle(Theme.textPrimary)

                    Text(style.blurb)
                        .font(Typo.micro)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(selected ? Theme.brand : Theme.textTertiary)
            }
            .padding(Space.sm)
            .cardSurface(shadow: selected ? .card : .tight)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Theme.brand : .clear, lineWidth: Stroke.thick)
            )
        }
        .buttonStyle(.plain)
        .jellyPress(scale: 0.98)
    }
}

struct StepRow: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Text("\(number)")
                .font(Typo.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(AppTint.grape.gradient))
                .overlay(Circle().strokeBorder(Theme.outline, lineWidth: 1.5))
            Text(text)
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

#Preview("Lock Screen studio") {
    LockScreenStudio().environment(AppState.preview)
}
