import WidgetKit
import SwiftUI

@main
struct NoPhoneWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudgetLockScreenWidget()
        BudgetHomeScreenWidget()
    }
}

// MARK: - Timeline

struct BudgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LockScreenSnapshot
}

struct BudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(BudgetEntry(date: .now, snapshot: SharedStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        // The app pushes a reload whenever usage changes, so the timeline is
        // just a safety net: one entry now, refreshed in fifteen minutes. A
        // tighter cadence would burn the widget's refresh budget for numbers
        // that only move while the phone is unlocked anyway.
        let entry = BudgetEntry(date: .now, snapshot: SharedStore.read())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Lock Screen widget

struct BudgetLockScreenWidget: Widget {
    private let kind = "NoPhoneBudgetLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetProvider()) { entry in
            BudgetAccessoryView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Time Left")
        .description("How much screen time each app has left today.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct BudgetAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: LockScreenSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(snapshot: snapshot, vibrant: false)
        case .accessoryInline:
            LockScreenInlineView(snapshot: snapshot)
        default:
            // Accessory widgets are rendered monochrome by the system, so the
            // shared renderer is asked for its non-vibrant variant: shape and
            // density carry the meaning instead of hue.
            LockScreenRectangularView(snapshot: snapshot, vibrant: false)
        }
    }
}

// MARK: - Home Screen widget

/// Full color, since Home Screen widgets keep their palette. Same data, but it
/// can afford the sticker treatment the Lock Screen has to give up.
struct BudgetHomeScreenWidget: Widget {
    private let kind = "NoPhoneBudgetHome"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetProvider()) { entry in
            HomeWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(hex: 0xFFF6E6), Color(hex: 0xFFEFF6)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Today's Time")
        .description("Your remaining screen time, in full color.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: LockScreenSnapshot

    var body: some View {
        if family == .systemSmall {
            VStack(spacing: 6) {
                Text("TIME LEFT")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Palette.inkFaint)
                BudgetRing(fraction: snapshot.totalFraction, tint: .mint,
                           lineWidth: 12, animated: false) {
                    Text(Fmt.clock(snapshot.totalRemaining))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .padding(4)
        } else {
            HStack(spacing: 12) {
                BudgetRing(fraction: snapshot.totalFraction, tint: .mint,
                           lineWidth: 11, animated: false) {
                    Text(Fmt.clock(snapshot.totalRemaining))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(snapshot.items.prefix(4)) { item in
                        HStack(spacing: 5) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(item.tint.deep)
                                .frame(width: 12)
                            WidgetBar(fraction: item.fraction, tint: item.tint)
                                .frame(height: 8)
                            Text(Fmt.short(item.remainingSeconds))
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(4)
        }
    }
}
