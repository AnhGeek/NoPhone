import SwiftUI

/// The actual Lock Screen widget renderers, shared by the in-app preview and
/// the widget extension so what you pick is exactly what you get.
///
/// Constraints that shape everything here: Lock Screen widgets are rendered
/// **monochrome-tinted** by the system in the accessory families, they sit on
/// an unknown wallpaper, and they are read in under a second. So each style
/// leans on *shape* and *fill density* rather than hue, keeps at most four
/// rows, and never renders text below 10pt.
///
/// `vibrant` switches between the real accessory rendering (system-tinted) and
/// the in-app preview (full color), which is the honest way to show both.
struct LockScreenRectangularView: View {
    let snapshot: LockScreenSnapshot
    /// True inside a real accessory widget, where color is stripped.
    var vibrant: Bool = true

    var body: some View {
        switch snapshot.style {
        case .rainbowStack: RainbowStackWidget(snapshot: snapshot, vibrant: vibrant)
        case .dials:        DialsWidget(snapshot: snapshot, vibrant: vibrant)
        case .blocks:       BlocksWidget(snapshot: snapshot, vibrant: vibrant)
        case .mascot:       MascotWidget(snapshot: snapshot, vibrant: vibrant)
        }
    }
}

// MARK: - Rainbow Stack

/// One thin bar per app, newest urgency at the top. The densest style — up to
/// four apps and their remaining minutes in a 160×70 slot.
struct RainbowStackWidget: View {
    let snapshot: LockScreenSnapshot
    var vibrant: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.system(size: 9, weight: .black))
                Text(Fmt.short(snapshot.totalRemaining).uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                Text("LEFT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .opacity(0.7)
                Spacer(minLength: 0)
            }
            .foregroundStyle(vibrant ? Theme.textPrimary : .primary)

            ForEach(snapshot.items.prefix(4)) { item in
                HStack(spacing: 5) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 8, weight: .black))
                        .frame(width: 10)
                    WidgetBar(fraction: item.fraction, tint: item.tint, vibrant: vibrant)
                        .frame(height: 7)
                    Text(Fmt.short(item.remainingSeconds))
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 26, alignment: .trailing)
                }
                .foregroundStyle(vibrant ? item.tint.deep : .primary)
            }
        }
        .widgetFrame()
    }
}

// MARK: - Dials

/// Concentric arcs — the whole day as one compact mark, plus a row of small
/// per-app rings. Best on busy wallpapers, where bars get lost.
struct DialsWidget: View {
    let snapshot: LockScreenSnapshot
    var vibrant: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(.primary.opacity(0.22), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: snapshot.totalFraction)
                    .stroke(vibrant ? AnyShapeStyle(AppTint.mint.gradient) : AnyShapeStyle(Color.primary),
                            style: .init(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Fmt.clock(snapshot.totalRemaining))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("TIME LEFT")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .opacity(0.7)
                HStack(spacing: 5) {
                    ForEach(snapshot.items.prefix(5)) { item in
                        ZStack {
                            Circle().stroke(.primary.opacity(0.22), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: item.fraction)
                                .stroke(vibrant ? AnyShapeStyle(item.tint.base) : AnyShapeStyle(Color.primary),
                                        style: .init(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: item.symbol)
                                .font(.system(size: 7, weight: .black))
                        }
                        .frame(width: 22, height: 22)
                    }
                }
            }
        }
        .foregroundStyle(vibrant ? Theme.textPrimary : .primary)
        .widgetFrame()
    }
}

// MARK: - Blocks

/// Ten pips per app. Loses precision, wins legibility — this is the style that
/// still works at arm's length or through a cracked screen protector.
struct BlocksWidget: View {
    let snapshot: LockScreenSnapshot
    var vibrant: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(snapshot.items.prefix(3)) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 8, weight: .black))
                        Text(item.name)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(Fmt.short(item.remainingSeconds))
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                    }
                    HStack(spacing: 2) {
                        ForEach(0..<10, id: \.self) { index in
                            let lit = Double(index) < (item.fraction * 10).rounded(.up)
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(lit
                                      ? (vibrant ? AnyShapeStyle(item.tint.base) : AnyShapeStyle(Color.primary))
                                      : AnyShapeStyle(Color.primary.opacity(0.2)))
                                .frame(height: 5)
                        }
                    }
                }
            }
        }
        .foregroundStyle(vibrant ? Theme.textPrimary : .primary)
        .widgetFrame()
    }
}

// MARK: - Mascot

/// Bloop plus one number. For people who want the nudge without the audit.
struct MascotWidget: View {
    let snapshot: LockScreenSnapshot
    var vibrant: Bool = true

    private var status: BudgetStatus {
        switch snapshot.totalFraction {
        case ..<0.001: .spent
        case ..<0.15:  .critical
        case ..<0.4:   .low
        default:       .healthy
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Mascot(mood: Mascot.Mood(status: status),
                   tint: vibrant ? .grape : .sky,
                   size: 46, animated: false)
                .saturation(vibrant ? 1 : 0)

            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.clock(snapshot.totalRemaining))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text(Fmt.clockUnit(snapshot.totalRemaining).uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .opacity(0.75)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(vibrant ? Theme.textPrimary : .primary)
        .widgetFrame()
    }
}

// MARK: - Circular & inline

/// The small round accessory: a single dial for the whole day.
struct LockScreenCircularView: View {
    let snapshot: LockScreenSnapshot
    var vibrant: Bool = true

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.22), lineWidth: 7)
            Circle()
                .trim(from: 0, to: snapshot.totalFraction)
                .stroke(vibrant ? AnyShapeStyle(AppTint.mint.gradient) : AnyShapeStyle(Color.primary),
                        style: .init(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Image(systemName: "hourglass")
                    .font(.system(size: 9, weight: .black))
                Text(Fmt.clock(snapshot.totalRemaining))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(vibrant ? Theme.textPrimary : .primary)
    }
}

/// The one-line accessory above the clock.
struct LockScreenInlineView: View {
    let snapshot: LockScreenSnapshot

    var body: some View {
        Label {
            Text("\(Fmt.short(snapshot.totalRemaining)) screen time left")
        } icon: {
            Image(systemName: "hourglass")
        }
    }
}

// MARK: - Shared bits

/// Bar used inside widgets — thinner outline and no gloss, because both get
/// destroyed by the system's vibrancy pass.
struct WidgetBar: View {
    var fraction: Double
    var tint: AppTint
    var vibrant: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.2))
                Capsule()
                    .fill(vibrant ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.primary))
                    .frame(width: max(fraction > 0 ? 6 : 0, geo.size.width * min(1, max(0, fraction))))
            }
        }
    }
}

private extension View {
    /// Accessory widgets clip hard; pinning to the leading/top edge keeps every
    /// style aligned to the same origin regardless of content height.
    func widgetFrame() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

extension LockScreenSnapshot {
    /// Placeholder rendered in a given style — used by previews and by the
    /// in-app style gallery.
    static func placeholder(style: LockScreenStyle) -> LockScreenSnapshot {
        var snapshot = LockScreenSnapshot.placeholder
        snapshot.style = style
        return snapshot
    }
}

#Preview("Widget styles") {
    VStack(spacing: Space.md) {
        ForEach(LockScreenStyle.allCases) { style in
            VStack(alignment: .leading) {
                Text(style.title).font(Typo.micro).foregroundStyle(.secondary)
                LockScreenRectangularView(snapshot: .placeholder(style: style))
                    .frame(width: 160, height: 72)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            }
        }
    }
    .padding()
    .background(Color.black)
}
