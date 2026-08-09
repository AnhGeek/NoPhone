import Foundation

/// Design-time data.
///
/// Tuned to exercise every visual state at once — one app already spent, one
/// critical, one healthy, one topped up with bonus time — so previews and
/// screenshots never show an unrealistically tidy day.
/// Preview fixtures. **Not a runtime data path.**
///
/// `apps` and `ledger` reach the UI only through `AppState.preview`: previews
/// and the Simulator have no Screen Time stack, so components still need
/// populated state to render all four budget statuses at once. Wiring these to
/// the default initializer would put invented usage next to real usage and make
/// every number in the app untrustworthy.
///
/// `quests` is different — it remains the documented stand-in for the admin's
/// backend catalog, and is still used at runtime.
enum SampleData {

    static let apps: [TrackedApp] = {
        let now = Date()
        func t(_ hoursAgo: Double) -> Date { now.addingTimeInterval(-hoursAgo * 3600) }

        return [
            TrackedApp(
                name: "Chirp", symbol: "bird.fill", tint: .sky, category: .social,
                budgetMinutes: 60, bonusMinutes: 0, usedMinutes: 58,
                sessions: [
                    UsageSession(start: t(9.5), minutes: 12),
                    UsageSession(start: t(7.0), minutes: 8),
                    UsageSession(start: t(5.2), minutes: 21),
                    UsageSession(start: t(2.1), minutes: 11),
                    UsageSession(start: t(0.6), minutes: 6)
                ]
            ),
            TrackedApp(
                name: "Loopz", symbol: "play.rectangle.fill", tint: .cherry, category: .video,
                budgetMinutes: 45, bonusMinutes: 15, usedMinutes: 60,
                sessions: [
                    UsageSession(start: t(11.0), minutes: 18),
                    UsageSession(start: t(6.4), minutes: 27),
                    UsageSession(start: t(1.2), minutes: 15)
                ]
            ),
            TrackedApp(
                name: "Pixel Pals", symbol: "gamecontroller.fill", tint: .grape, category: .games,
                budgetMinutes: 90, bonusMinutes: 20, usedMinutes: 44,
                sessions: [
                    UsageSession(start: t(8.2), minutes: 25),
                    UsageSession(start: t(3.0), minutes: 19)
                ]
            ),
            TrackedApp(
                name: "Snapbox", symbol: "camera.fill", tint: .bubblegum, category: .social,
                budgetMinutes: 40, bonusMinutes: 0, usedMinutes: 31,
                sessions: [
                    UsageSession(start: t(10.1), minutes: 9),
                    UsageSession(start: t(4.5), minutes: 14),
                    UsageSession(start: t(0.9), minutes: 8)
                ]
            ),
            TrackedApp(
                name: "Chatter", symbol: "bubble.left.and.bubble.right.fill",
                tint: .mint, category: .messaging,
                budgetMinutes: 75, bonusMinutes: 0, usedMinutes: 22,
                sessions: [
                    UsageSession(start: t(12.0), minutes: 6),
                    UsageSession(start: t(5.5), minutes: 9),
                    UsageSession(start: t(1.4), minutes: 7)
                ]
            ),
            TrackedApp(
                name: "Shopmoji", symbol: "bag.fill", tint: .tangerine, category: .shopping,
                budgetMinutes: 30, bonusMinutes: 0, usedMinutes: 7,
                sessions: [UsageSession(start: t(6.9), minutes: 7)],
                pinnedToLockScreen: false
            )
        ]
    }()

    /// Quest catalog. Reward minutes here stand in for admin-configured values
    /// delivered by the backend — the client never edits them.
    static let quests: [Quest] = [
        Quest(title: "Make your bed",
              detail: "Two minutes of tidy, a whole day of calm.",
              symbol: "bed.double.fill", tint: .sky,
              rewardMinutes: 5, cadence: .daily, maxPerWindow: 1),

        Quest(title: "Walk 3,000 steps",
              detail: "Outside counts double for your mood.",
              symbol: "figure.walk", tint: .mint,
              rewardMinutes: 15, cadence: .daily, maxPerWindow: 2),

        Quest(title: "Read 20 pages",
              detail: "Paper, e-ink, or comics — all fair game.",
              symbol: "book.fill", tint: .tangerine,
              rewardMinutes: 20, cadence: .daily, maxPerWindow: 1),

        Quest(title: "Homework done",
              detail: "Finish the set that's due tomorrow.",
              symbol: "pencil.and.ruler.fill", tint: .grape,
              rewardMinutes: 25, cadence: .daily, maxPerWindow: 1),

        Quest(title: "Dishes duty",
              detail: "Load it, run it, put it away.",
              symbol: "sink.fill", tint: .bubblegum,
              rewardMinutes: 10, cadence: .daily, maxPerWindow: 1),

        Quest(title: "Phone-free dinner",
              detail: "Whole meal, no screens at the table.",
              symbol: "fork.knife", tint: .sunshine,
              rewardMinutes: 20, cadence: .daily, maxPerWindow: 1),

        // Premium tier — visible to everyone, claimable by Champions only.
        Quest(title: "Deep work sprint",
              detail: "45 focused minutes. No tab-hopping.",
              symbol: "brain.head.profile", tint: .grape,
              rewardMinutes: 40, tier: .premium, cadence: .daily, maxPerWindow: 2),

        Quest(title: "Weekly reset",
              detail: "Plan the week ahead every Sunday.",
              symbol: "calendar.badge.clock", tint: .sky,
              rewardMinutes: 60, tier: .premium, cadence: .weekly, maxPerWindow: 1),

        Quest(title: "Teach someone something",
              detail: "Show a friend or family member a new trick.",
              symbol: "graduationcap.fill", tint: .mint,
              rewardMinutes: 30, tier: .premium, cadence: .weekly, maxPerWindow: 2)
    ]

    static let ledger: [RewardGrant] = [
        RewardGrant(questTitle: "Walk 3,000 steps", minutes: 15,
                    grantedAt: .now.addingTimeInterval(-3600 * 2),
                    appName: nil, symbol: "figure.walk", tint: .mint),
        RewardGrant(questTitle: "Read 20 pages", minutes: 20,
                    grantedAt: .now.addingTimeInterval(-3600 * 6),
                    appName: "Pixel Pals", symbol: "book.fill", tint: .tangerine)
    ]
}
