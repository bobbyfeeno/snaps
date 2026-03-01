import SwiftUI

struct GameRule: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let rules: String
}

private let allRules: [GameRule] = [
    GameRule(emoji: "📋", name: "Keep Score", rules: "Standard golf scorecard. Track every player's score hole-by-hole with no side bets attached. Combine it with any other game mode for a full picture of the round."),

    GameRule(emoji: "🏆", name: "Head to Head", rules: "The purest form of golf competition — you win holes, not strokes.\n\nMatch Play: Each hole is won, halved, or lost. Win a hole by having the lower score. Tie a hole = halve it. Track as \"X UP\" or \"X DOWN.\" Match ends when someone is mathematically unbeatable. Final margin shown as \"3&2\" — 3 holes up with 2 remaining.\n\nStroke Play: Lowest net total over 18 holes wins. Payout = bet × stroke difference.\n\nPress: When a player goes 2-down, a new side bet automatically starts covering the remaining holes.\n\nHandicaps: Strokes allocated using USGA-style hole difficulty ratings.\n\nMulti-player: With 3+ players, every pair plays their own independent match simultaneously."),

    GameRule(emoji: "💰", name: "Tax Man", rules: "Each player sets a Tax Man number — their personal target score for 18 holes.\n\nShoot ABOVE your number → pay every player who shot BELOW theirs.\nShoot BELOW your number → collect from every player who shot ABOVE theirs.\n\nThe lower your number, the harder it is to beat — but the bigger the payday when you do."),

    GameRule(emoji: "🏅", name: "Nassau", rules: "Three bets in one: Front 9, Back 9, and Full 18. The player with the lowest score on each segment wins that bet.\n\nStroke Play: Total strokes decide the winner.\nMatch Play: Win holes one at a time — whoever wins the most holes takes the bet.\n\nPress: When a player goes 2-down, a new side bet starts for the remaining holes. This app uses auto-press (triggers automatically at 2-down), the most common variant."),

    GameRule(emoji: "🎯", name: "Skins", rules: "Each hole is worth a skin (dollar amount you set). Lowest score on a hole wins the skin outright — but only if nobody ties. Ties roll the skin over to the next hole, letting the pot grow. A skin worth 5× what you started with is where legends are made."),

    GameRule(emoji: "🐺", name: "Wolf", rules: "One player is the \"Wolf\" each hole, rotating in order. The Wolf tees off first, then watches each opponent hit one at a time. After each drive, the Wolf must decide: pick that player as a partner right now — or pass. Once you pass a player, you can't go back.\n\nYour options:\n🐺 Partner Wolf — Pick someone. The pair plays the other two for the set bet.\n🔥 Solo Wolf (×2) — Pass all three opponents. Go 1v3 for double the bet.\n⚡ Lone Wolf (×3) — Declare solo right after your own drive, before anyone else tees off.\n🕶️ Blind Wolf (×4) — Declare solo before you even hit your own drive. 4× the bet.\n\nOn holes 17 and 18, the player in last place chooses which hole to be Wolf, and 3rd takes the other."),

    GameRule(emoji: "🎯", name: "Bingo Bango Bongo", rules: "Three points are available every hole:\n\n🟢 Bingo — First ball on the green\n📍 Bango — Closest to the pin once all balls are on the green\n🕳️ Bongo — First ball in the hole\n\nEach point is worth the dollar amount you set. Great equalizer — any skill level can grab points. Play in order of farthest from pin to keep it fair."),

    GameRule(emoji: "🐍", name: "Snake", rules: "The last player to 3-putt holds the snake 🐍. You're stuck with it until someone else 3-putts — then it passes to them. Whoever holds the snake at the end of the round pays every other player the snake bet.\n\nNever 3-putt? Never touch the snake. 3-putt on 18? Ouch."),

    GameRule(emoji: "🎰", name: "Vegas", rules: "A 2v2 team game where each team's scores combine into a 2-digit number. Lower team number wins the hole.\n\nWhen either player makes par or better → lower digit goes first (4 and 6 = \"46\").\nWhen BOTH make bogey or worse → higher digit goes first (4 and 6 = \"64\").\nDouble-digit scores (10+): the double-digit number always goes first.\n\nPayout: difference between the two team numbers × your bet per point.\n\nFlip the Bird 🐦 (optional): birdie flips your opponent's digits.\nHammer 🔨: either team can double the stakes mid-hole."),

    GameRule(emoji: "⚔️", name: "Best Ball", rules: "A 2v2 team game. All four players play their own ball every hole — but only the BEST (lowest) score on each hole counts for the team.\n\nStroke Play: Add up the best scores over 18 holes. Lower team total wins the full bet × stroke difference.\n\nMatch Play: Win holes outright with a lower team score. Most holes won takes the pot. Ties push."),

    GameRule(emoji: "📊", name: "Stableford", rules: "Points awarded per hole based on your score vs par:\n\n🌟 Albatross (3 under) = 5 points\n🦅 Eagle = 4 points\n🐦 Birdie = 3 points\n⛳ Par = 2 points\n👎 Bogey = 1 point\n💀 Double bogey or worse = 0 points\n\nHighest total points wins. Each losing player pays each winner your dollar amount × the point difference.\n\nBlow-up holes cap at 0 — you can never go negative, so bad holes hurt less than stroke play."),

    GameRule(emoji: "🐰", name: "Rabbit", rules: "One rabbit, 18 holes, and a whole lot of pressure.\n\nThe first player to win a hole outright (lowest score, no ties) \"catches the rabbit.\" They hold it until another player wins a hole outright — then the rabbit jumps to them.\n\nWhoever holds the rabbit at the end of the round COLLECTS from every other player. Catching the rabbit is good — holding it is better.\n\nIf nobody ever wins a hole outright, no payout."),

    GameRule(emoji: "⭐", name: "Dots / Junk", rules: "Side bets rewarding great shots. Every dot you earn costs every other player your set dollar amount.\n\n🐦 Birdie — 1 under par = 1 dot (auto-tracked)\n🦅 Eagle — 2+ under par = 2 dots (auto-tracked)\n🏖️ Sandy — get up-and-down from a bunker (one shot out + par or better) = 1 dot\n🌿 Greenie — par 3 only; tee shot must land on the green; closest to pin who makes par or better = 1 dot\n\nToggle which dot types are active during setup. Dots stack on top of any other game."),

    GameRule(emoji: "6️⃣", name: "Sixes", rules: "A 4-player game where partners rotate every 6 holes.\n\nSegment 1 (Holes 1–6): Player 1 & 2 vs Player 3 & 4\nSegment 2 (Holes 7–12): Player 1 & 3 vs Player 2 & 4\nSegment 3 (Holes 13–18): Player 1 & 4 vs Player 2 & 3\n\nEach segment is match play — lowest score wins each hole. The team that wins the most holes in a segment collects from each opponent. Ties within a segment push."),

    GameRule(emoji: "9️⃣", name: "Nines", rules: "A 3-player game where 9 points are distributed every hole.\n\nBest score = 5 points. Second = 3 points. Worst = 1 point.\n\nTie rules:\n• Two tie for best: each gets 4 pts, worst gets 1\n• Two tie for worst: best gets 5, each of the two gets 2\n• All tie: 3 pts each\n\nAt the end, players settle based on total point differences × your dollar amount per point."),

    GameRule(emoji: "🥃", name: "Scotch", rules: "A 2v2 team points game. This app plays a simplified Low Ball / Low Total format — 5 points per hole.\n\n2 points — Low Ball: whichever team has the lower individual score wins 2 pts.\n3 points — Low Total: whichever team has the lower combined score wins 3 pts.\n\nA clean sweep wins all 5 pts. Ties on either category push.\n\nPoint difference × your dollar amount determines the payout.\n\nNote: Traditional 5-point Scotch includes five categories. This app plays a simplified 2-category version."),

    GameRule(emoji: "⛳", name: "Closest to Pin", rules: "A par 3 side bet. On each par 3, whoever's tee shot comes to rest on the green closest to the pin collects from every other player.\n\nKey rule: the ball must be ON the green from the tee shot to qualify. A ball that misses the green is not eligible — even if it ends up closer than everyone else.\n\nMark the CTP winner manually in the scorecard tracker."),

    GameRule(emoji: "🎲", name: "Aces & Deuces", rules: "Every hole has an Ace (best score) and a Deuce (worst score) — and everyone is in the action.\n\nStandard payout:\n• The Ace collects the set amount from EVERY other player\n• The Deuce pays the set amount to EVERY other player\n• Middle scores pay the Ace and collect from the Deuce — netting to $0 with equal bets\n\nIf everyone ties, it's always a push. Stacks well alongside any other game."),

    GameRule(emoji: "📈", name: "Quota", rules: "A personal points challenge layered on top of Stableford scoring.\n\nBefore the round, each player sets their quota — a target Stableford points total.\n\nStandard formula: Quota = 36 minus your course handicap\n(Scratch = 36 · 10-hdcp = 26 · 18-hdcp = 18)\n\nScoring per hole: Albatross = 5 · Eagle = 4 · Birdie = 3 · Par = 2 · Bogey = 1 · Double+ = 0\n\nAt the end:\n• Beat your quota → collect (points over quota × dollar amount) from each player who missed\n• Miss your quota → pay each player who beat theirs\n\nGreat equalizer — different skill levels compete fairly because each quota is calibrated to handicap."),

    GameRule(emoji: "😈", name: "Trouble", rules: "Pay for your mistakes.\n\nAgree which trouble categories are in play. When a player hits trouble, they pay every other player the set dollar amount — one charge per occurrence.\n\nTrouble types:\n🚩 OB (out of bounds)\n💧 Water hazard\n3️⃣ 3-Putt\n🏖️ Sand trap\n🔍 Lost ball\n\nMultiple troubles on one hole stack — go OB and 3-putt and you're paying twice.\n\nTrack trouble manually in the scorecard panel during your round."),

    GameRule(emoji: "🦁", name: "Arnies", rules: "Named after Arnold Palmer — making par or better from off the fairway the ENTIRE hole.\n\nTo earn an Arnie, you must:\n1. Make par or better on the hole\n2. Never have your ball on the fairway at any point\n3. Be on a par-4 or par-5 — par-3s don't count\n\nPlaying from rough, trees, bunkers, or any non-fairway surface all the way to the green — and still making par. Even a ball that rolls through the edge of the fairway disqualifies.\n\nWhen you pull it off, every other player pays you the set amount."),

    GameRule(emoji: "🏦", name: "Banker", rules: "One player is the Banker each hole — everyone else plays against them individually.\n\nAll other players compete against the Banker in stroke play, head-to-head:\n• Beat the Banker → Banker pays you\n• Lose to the Banker → you pay the Banker\n• Tie → push\n\nThe Banker wins or loses against each opponent separately.\n\nStandard assignment: whoever won the previous hole becomes the next Banker. Tied hole: current Banker retains. Banker always tees off last.\n\nThis app lets the Banker set a custom bet amount each hole — tap the Banker panel to adjust."),

    GameRule(emoji: "🔨", name: "Hammer", rules: "A bet-doubling modifier that stacks on top of other hole-based games.\n\nOn any hole, any player (or team) can call \"Hammer!\" — doubling the value of that hole's bet.\n\nThe opponent must accept or concede:\n• Accept — hole continues at doubled value. The receiving side can immediately re-Hammer back.\n• Concede — hole is over. Hammering side wins at the previous (un-doubled) value.\n\nMultipliers stack: ×1 → ×2 → ×4 → ×8 → ×16\n\nTap the ×N cell in the scorecard on any active hole to call, accept, re-hammer, or concede."),
]

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var expandedId: UUID? = nil

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Header row — inline at top of scroll
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer()

                    Text("ALL GAME RULES")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(theme.textPrimary)
                        .tracking(2)

                    Spacer()

                    Color.clear.frame(width: 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Rules list — starts immediately
                ForEach(Array(allRules.enumerated()), id: \.element.id) { index, rule in
                    RuleCard(
                        index: index + 1,
                        rule: rule,
                        isExpanded: expandedId == rule.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            expandedId = expandedId == rule.id ? nil : rule.id
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(theme.bg.ignoresSafeArea())
    }
}

struct RuleCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let index: Int
    let rule: GameRule
    let isExpanded: Bool
    let onTap: () -> Void

    private var theme: SnapsTheme { SnapsTheme(colorScheme: colorScheme) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Row header
                HStack(spacing: 12) {
                    Text("\(index)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.textMuted)
                        .frame(width: 20, alignment: .trailing)

                    Text(rule.emoji)
                        .font(.system(size: 24))

                    Text(rule.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isExpanded ? Color.snapsGreen : theme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                // Expanded rules
                if isExpanded {
                    Divider()
                        .background(theme.border)
                        .padding(.horizontal, 16)

                    Text(rule.rules)
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isExpanded ? Color.snapsGreen.opacity(0.25) : theme.border,
                                lineWidth: 1
                            )
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
        }
        .buttonStyle(SnapsButtonStyle())
    }
}
