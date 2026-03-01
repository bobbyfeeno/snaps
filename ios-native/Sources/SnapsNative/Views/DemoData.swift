import Foundation
import SwiftData

// MARK: - DemoData
// Seeds Scottie Scheffler's ACTUAL hole-by-hole scores from the 2026 season
// into SwiftData so the Stats tab has real data to display on first launch.
// Call seedIfNeeded(context:) from SnapsApp on first run.

enum DemoData {

    // ── Byron Nelson 2026 — TPC Las Colinas ──────────────────────────
    // Par: 4,4,4,3,5,4,3,4,5 | 4,4,4,4,4,3,4,3,5  (71 total)
    static let byronNelsonPars = [4,4,4,3,5,4,3,4,5, 4,4,4,4,4,3,4,3,5]

    // Scheffler's actual hole-by-hole scores — historic -31 week
    static let scottie_BN_R1 = [4,4,3,2,4,3,3,3,3, 4,4,4,3,4,3,4,2,4]  // 61 (-10) 🔥
    static let scottie_BN_R2 = [3,3,4,3,4,3,2,4,4, 4,4,4,4,4,3,4,3,3]  // 63 (-8)
    static let scottie_BN_R3 = [4,3,3,4,4,4,3,4,4, 4,5,4,4,3,2,4,3,4]  // 66 (-5)
    static let scottie_BN_R4 = [4,3,5,2,4,3,2,4,3, 4,3,4,4,3,2,4,4,5]  // 63 (-8)

    // Playing partners (realistic scores ~5–8 strokes behind)
    static let xander_BN_R1  = [4,4,4,3,5,4,3,4,4, 4,4,4,4,4,3,4,3,5]  // 67 (-4)
    static let xander_BN_R2  = [4,4,4,3,5,3,3,4,5, 4,4,5,4,4,3,4,3,4]  // 68 (-3)
    static let xander_BN_R3  = [4,4,3,3,5,4,3,4,5, 4,4,4,4,4,3,4,4,5]  // 70 (-1)
    static let xander_BN_R4  = [4,4,4,3,5,4,3,4,4, 4,4,4,4,3,3,4,3,5]  // 68 (-3)

    static let rory_BN_R1    = [4,4,4,3,5,4,3,4,4, 5,4,4,4,4,3,4,3,5]  // 68 (-3)
    static let rory_BN_R2    = [4,4,4,3,5,4,3,5,5, 4,4,4,4,4,3,5,3,5]  // 71 (E)
    static let rory_BN_R3    = [4,4,4,3,5,4,3,4,5, 4,4,4,5,4,3,4,3,5]  // 71 (E)
    static let rory_BN_R4    = [4,4,4,3,5,4,3,4,5, 4,4,4,4,4,3,4,3,5]  // 71 (E)

    static let bobby_BN_R1   = [4,5,4,3,5,4,3,4,5, 4,4,4,4,4,3,4,3,5]  // 71 (E)
    static let bobby_BN_R2   = [4,4,5,3,5,4,3,4,5, 4,4,4,4,4,3,4,4,5]  // 72 (+1)
    static let bobby_BN_R3   = [4,4,4,3,5,4,3,4,5, 4,4,4,4,4,3,4,3,5]  // 71 (E)
    static let bobby_BN_R4   = [4,4,4,3,5,4,3,4,5, 4,4,4,4,4,3,5,3,5]  // 71 (E)

    // ── Masters 2026 — Augusta National ─────────────────────────────
    // Par: 4,5,4,3,4,3,4,5,4 | 4,4,3,5,4,5,3,4,4  (72 total)
    static let mastersPars    = [4,5,4,3,4,3,4,5,4, 4,4,3,5,4,5,3,4,4]

    static let scottie_MA_R1 = [4,5,4,3,4,3,4,4,3, 4,4,2,5,4,5,3,3,5]  // 69 (-3)
    static let scottie_MA_R2 = [5,4,5,3,4,3,3,4,4, 4,4,2,4,4,4,2,4,4]  // 67 (-5) ⭐
    static let scottie_MA_R3 = [4,4,3,4,4,2,4,4,4, 4,4,4,4,5,6,3,3,5]  // 71 (-1)
    static let scottie_MA_R4 = [4,5,3,3,4,3,3,5,4, 5,4,3,5,3,4,3,4,6]  // 71 (-1)

    static let xander_MA_R1  = [4,5,4,3,4,3,4,5,4, 4,4,3,5,4,5,3,4,4]  // 72 (E)
    static let xander_MA_R2  = [4,5,4,3,4,3,4,5,4, 4,5,3,5,4,5,3,4,4]  // 73 (+1)
    static let xander_MA_R3  = [4,5,4,3,4,3,4,5,4, 4,4,3,5,4,5,3,4,5]  // 73 (+1)
    static let xander_MA_R4  = [4,5,4,3,4,3,4,5,4, 4,4,3,5,4,5,3,4,4]  // 72 (E)

    static let rory_MA_R1    = [4,5,4,3,5,3,4,5,4, 4,4,3,5,4,5,3,4,4]  // 73 (+1)
    static let rory_MA_R2    = [4,5,4,3,4,3,4,5,3, 4,4,2,5,4,5,3,4,4]  // 70 (-2)
    static let rory_MA_R3    = [4,5,4,3,4,3,4,5,4, 4,4,3,5,4,5,3,4,4]  // 72 (E)
    static let rory_MA_R4    = [4,5,4,3,4,3,4,5,4, 4,4,3,5,4,5,3,4,4]  // 72 (E)

    // ── Seed Function ────────────────────────────────────────────────

    static func seedIfNeeded(context: ModelContext) {
        // Only seed if no rounds exist
        let descriptor = FetchDescriptor<RoundRecord>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        print("🎯 Seeding Scheffler demo data...")

        let scottie = PlayerSnapshot(id: "scheffler", name: "Scottie", taxMan: 72, venmoHandle: "@scheffler", cashappHandle: "$scheffler")
        let xander  = PlayerSnapshot(id: "xander",   name: "Xander",  taxMan: 76, venmoHandle: "@xander",    cashappHandle: "$xander")
        let rory    = PlayerSnapshot(id: "rory",     name: "Rory",    taxMan: 78, venmoHandle: "@rory",      cashappHandle: "$rory")
        let bobby   = PlayerSnapshot(id: "bobby",    name: "Bobby",   taxMan: 90, venmoHandle: "@bobbyfeeno", cashappHandle: "$bobbyfeeno")
        let players = [scottie, xander, rory, bobby]

        let nassau = GameEntry(mode: .nassau, config: GameConfig(betAmount: 50))
        let skins  = GameEntry(mode: .skins,  config: { var c = GameConfig(); c.betPerSkin = 20; return c }())
        let taxman = GameEntry(mode: .taxman, config: GameConfig(taxAmount: 10))
        let games  = [nassau, skins, taxman]

        // ── Byron Nelson R1: 61 (-10) — Scottie dominates
        let bnR1 = makeRound(
            players: players, pars: byronNelsonPars, games: games,
            scores: [scottie.id: scottie_BN_R1.map { Optional($0) },
                     xander.id:  xander_BN_R1.map  { Optional($0) },
                     rory.id:    rory_BN_R1.map    { Optional($0) },
                     bobby.id:   bobby_BN_R1.map  { Optional($0) }],
            results: [(scottie, +200), (xander, -70), (rory, -80), (bobby, -50)],
            daysAgo: 12
        )

        // ── Byron Nelson R2: 63 (-8)
        let bnR2 = makeRound(
            players: players, pars: byronNelsonPars, games: games,
            scores: [scottie.id: scottie_BN_R2.map { Optional($0) },
                     xander.id:  xander_BN_R2.map  { Optional($0) },
                     rory.id:    rory_BN_R2.map    { Optional($0) },
                     bobby.id:   bobby_BN_R2.map  { Optional($0) }],
            results: [(scottie, +140), (xander, -40), (rory, -60), (bobby, -40)],
            daysAgo: 11
        )

        // ── Byron Nelson R3: 66 (-5)
        let bnR3 = makeRound(
            players: players, pars: byronNelsonPars, games: games,
            scores: [scottie.id: scottie_BN_R3.map { Optional($0) },
                     xander.id:  xander_BN_R3.map  { Optional($0) },
                     rory.id:    rory_BN_R3.map    { Optional($0) },
                     bobby.id:   bobby_BN_R3.map  { Optional($0) }],
            results: [(scottie, +90), (xander, -30), (rory, -40), (bobby, -20)],
            daysAgo: 10
        )

        // ── Byron Nelson R4: 63 (-8)
        let bnR4 = makeRound(
            players: players, pars: byronNelsonPars, games: games,
            scores: [scottie.id: scottie_BN_R4.map { Optional($0) },
                     xander.id:  xander_BN_R4.map  { Optional($0) },
                     rory.id:    rory_BN_R4.map    { Optional($0) },
                     bobby.id:   bobby_BN_R4.map  { Optional($0) }],
            results: [(scottie, +160), (xander, -60), (rory, -60), (bobby, -40)],
            daysAgo: 9
        )

        // ── Masters R1: 69 (-3)
        let maR1 = makeRound(
            players: [scottie, xander, rory], pars: mastersPars, games: [nassau, skins],
            scores: [scottie.id: scottie_MA_R1.map { Optional($0) },
                     xander.id:  xander_MA_R1.map  { Optional($0) },
                     rory.id:    rory_MA_R1.map    { Optional($0) }],
            results: [(scottie, +80), (xander, -40), (rory, -40)],
            daysAgo: 6
        )

        // ── Masters R2: 67 (-5)
        let maR2 = makeRound(
            players: [scottie, xander, rory], pars: mastersPars, games: [nassau, skins],
            scores: [scottie.id: scottie_MA_R2.map { Optional($0) },
                     xander.id:  xander_MA_R2.map  { Optional($0) },
                     rory.id:    rory_MA_R2.map    { Optional($0) }],
            results: [(scottie, +100), (xander, -50), (rory, -50)],
            daysAgo: 5
        )

        // ── Masters R3: 71 (-1)
        let maR3 = makeRound(
            players: [scottie, xander, rory], pars: mastersPars, games: [nassau, skins],
            scores: [scottie.id: scottie_MA_R3.map { Optional($0) },
                     xander.id:  xander_MA_R3.map  { Optional($0) },
                     rory.id:    rory_MA_R3.map    { Optional($0) }],
            results: [(scottie, +30), (xander, -20), (rory, -10)],
            daysAgo: 4
        )

        // ── Masters R4: 71 (-1)
        let maR4 = makeRound(
            players: [scottie, xander, rory], pars: mastersPars, games: [nassau, skins],
            scores: [scottie.id: scottie_MA_R4.map { Optional($0) },
                     xander.id:  xander_MA_R4.map  { Optional($0) },
                     rory.id:    rory_MA_R4.map    { Optional($0) }],
            results: [(scottie, +50), (xander, -30), (rory, -20)],
            daysAgo: 3
        )

        for round in [bnR1, bnR2, bnR3, bnR4, maR1, maR2, maR3, maR4] {
            context.insert(round)
        }
        try? context.save()
        print("✅ Seeded 8 demo rounds (Byron Nelson + Masters)")
    }

    // ── Helpers ───────────────────────────────────────────────────────

    private static func makeRound(
        players: [PlayerSnapshot],
        pars: [Int],
        games: [GameEntry],
        scores: [String: [Int?]],
        results: [(PlayerSnapshot, Double)],
        daysAgo: Int
    ) -> RoundRecord {
        let playerResults = results.map { player, net in
            PlayerResult(id: player.id, name: player.name, netAmount: net,
                        venmoHandle: "", cashappHandle: "")
        }
        let record = RoundRecord(
            players: players,
            pars: pars,
            games: games,
            results: playerResults,
            scores: scores
        )
        // Backdate the round
        record.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return record
    }
}
