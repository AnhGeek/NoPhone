import SwiftUI

/// A to-scale iPhone Lock Screen mock.
///
/// Proportions follow a modern iPhone (roughly 19.5:9, 55pt corner radius
/// scaled to the frame). The point is fidelity: the widget must be previewed
/// at real size, under a wallpaper, at the real distance below the clock —
/// otherwise the preview flatters the design.
struct PhoneFrame<Content: View>: View {
    var wallpaper: WallpaperPreset
    var width: CGFloat = 268
    @ViewBuilder var content: () -> Content

    private var height: CGFloat { width * 2.16 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.19, style: .continuous)
                .fill(wallpaper.gradient)

            // Wallpaper "subject" — a soft blob so the widgets are seen over
            // something, the way they will be in real life.
            Blob(points: 7)
                .fill(.white.opacity(0.12))
                .frame(width: width * 0.9, height: width * 0.9)
                .blur(radius: 20)
                .offset(y: height * 0.22)

            content()
                .padding(.horizontal, width * 0.085)

            // Bezel and hardware.
            RoundedRectangle(cornerRadius: width * 0.19, style: .continuous)
                .strokeBorder(Palette.ink, lineWidth: 7)

            RoundedRectangle(cornerRadius: width * 0.19 + 4, style: .continuous)
                .strokeBorder(Color(hex: 0x3B3358), lineWidth: 3)
                .padding(-3)

            VStack {
                Capsule()
                    .fill(.black)
                    .frame(width: width * 0.3, height: width * 0.09)
                    .padding(.top, width * 0.045)
                Spacer()
                Capsule()
                    .fill(.white.opacity(0.65))
                    .frame(width: width * 0.35, height: 5)
                    .padding(.bottom, width * 0.035)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.19, style: .continuous))
        .shadow(color: Palette.ink.opacity(0.35), radius: 24, y: 14)
    }
}

/// Everything that lives on the Lock Screen: status bar, date, clock, widget
/// row, and the two corner buttons.
struct LockScreenContent: View {
    let snapshot: LockScreenSnapshot
    var wallpaper: WallpaperPreset

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Spacer().frame(height: 26)

            // A circular accessory sits above the clock, exactly where iOS puts it.
            HStack(spacing: 10) {
                Spacer()
                LockScreenInlineView(snapshot: snapshot)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }

            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 4)

            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: 66, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)

            // The main event: the rectangular accessory widget.
            LockScreenRectangularView(snapshot: snapshot, vibrant: false)
                .foregroundStyle(.white)
                .frame(height: 74)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                )
                .padding(.top, 8)

            Spacer()

            notification

            HStack {
                lockButton("flashlight.off.fill")
                Spacer()
                lockButton("camera.fill")
            }
            .padding(.bottom, 34)
        }
    }

    private var statusBar: some View {
        HStack {
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: 11, weight: .bold, design: .rounded))
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.75")
            }
            .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.top, 14)
    }

    /// A NoPhone notification, so the mock shows how the app speaks when it
    /// interrupts. Tone check: informative, never scolding.
    private var notification: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTint.grape.gradient))

            VStack(alignment: .leading, spacing: 1) {
                Text("NoPhone")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text(notificationLine)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.18)))
        .padding(.bottom, 14)
    }

    private var notificationLine: String {
        if snapshot.totalFraction <= 0.001 {
            return "Today's time is spent. Bars refill at midnight."
        }
        if let tightest = snapshot.items.first, tightest.fraction <= 0.2 {
            return "\(tightest.name) has \(Fmt.short(tightest.remainingSeconds)) left."
        }
        return "\(Fmt.short(snapshot.totalRemaining)) left today. Nicely paced."
    }

    private func lockButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(Circle().fill(.white.opacity(0.2)))
    }
}

/// Preview wallpapers. Chosen to stress-test the widget: a bright one, a dark
/// one, a busy one, and a flat one.
enum WallpaperPreset: String, CaseIterable, Identifiable {
    case sunrise, midnight, candy, mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunrise:  "Dawn"
        case .midnight: "Night"
        case .candy:    "Candy"
        case .mint:     "Mint"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .sunrise:
            LinearGradient(colors: [Color(hex: 0xFF9A6B), Color(hex: 0xFF6BA9), Color(hex: 0x9B6BFF)],
                           startPoint: .top, endPoint: .bottom)
        case .midnight:
            LinearGradient(colors: [Color(hex: 0x1A1338), Color(hex: 0x3B2A78), Color(hex: 0x120C29)],
                           startPoint: .top, endPoint: .bottom)
        case .candy:
            LinearGradient(colors: [Color(hex: 0x4FB8FF), Color(hex: 0xFF6BA9), Color(hex: 0xFFCB3D)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mint:
            LinearGradient(colors: [Color(hex: 0x3ED9A4), Color(hex: 0x1E8FE0)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

#Preview("Phone frame") {
    ScrollView {
        VStack(spacing: Space.lg) {
            ForEach(WallpaperPreset.allCases) { preset in
                PhoneFrame(wallpaper: preset) {
                    LockScreenContent(snapshot: .placeholder, wallpaper: preset)
                }
            }
        }
        .padding()
    }
    .background(Theme.canvas)
}
