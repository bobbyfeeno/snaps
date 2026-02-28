import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  ImageBackground,
  LayoutAnimation,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  UIManager,
  View,
} from 'react-native';

interface GameRule {
  emoji: string;
  name: string;
  rules: string;
}

const GAMES: GameRule[] = [
  {
    emoji: '📋',
    name: 'Keep Score',
    rules: `Standard golf scorecard. Track every player's score hole-by-hole with no side bets attached. Combine it with any other game mode for a full picture of the round.`,
  },
  {
    emoji: '💰',
    name: 'Tax Man',
    rules: `Each player sets a Tax Man number — their personal target score for 18 holes.\n\nIf you shoot ABOVE your number, you pay every player who shot BELOW their number.\n\nIf you shoot BELOW your number, you collect from every player who shot ABOVE theirs.\n\nThe lower your number, the harder it is to beat — but the bigger the payday when you do.`,
  },
  {
    emoji: '🏌️',
    name: 'Nassau',
    rules: `Three bets in one: Front 9, Back 9, and Full 18. The player with the lowest score on each segment wins that bet.\n\nStroke Play: Total strokes decide the winner.\nMatch Play: Win holes one at a time — whoever wins the most holes takes the bet.\n\nPress: When a player goes 2-down, they can call a press — starting a new side bet for the remaining holes. Presses can stack. This app uses auto-press (triggers automatically at 2-down), which is the most common variant. Some groups require the losing side to offer the press and the opponent to accept — agree before the round.`,
  },
  {
    emoji: '🎰',
    name: 'Skins',
    rules: `Each hole is worth a skin (dollar amount you set). Lowest score on a hole wins the skin outright — but only if nobody ties. Ties roll the skin over to the next hole, letting the pot grow. A skin worth 5× what you started with is where legends are made.`,
  },
  {
    emoji: '🐺',
    name: 'Wolf',
    rules: `One player is the "Wolf" each hole, rotating in order. The Wolf tees off first, then watches each opponent hit one at a time. After each drive, the Wolf must decide: pick that player as a partner right now — or pass. Once you pass a player, you can't go back.\n\nThe Wolf must commit before the next player tees off.\n\nYour options:\n🐺 Partner Wolf — Pick someone. The chosen pair plays the other two for the set bet.\n🔥 Solo Wolf (×2) — Pass all three opponents. Go 1v3 for double the bet.\n⚡ Lone Wolf (×3) — Declare solo right after your own drive, before anyone else tees off. Higher risk, triple the reward.\n🕶️ Blind Wolf (×4) — Declare solo before you even hit your own drive. Maximum risk, 4× the bet.\n\nWolf rotates each hole. On holes 17 and 18, the player in last place chooses which hole to be Wolf, and the player in 3rd takes the other — giving the trailing players a chance to swing the match. Some groups give it to the leaders instead; agree before the round.`,
  },
  {
    emoji: '🎯',
    name: 'Bingo Bango Bongo',
    rules: `Three points are available every hole:\n\n🟢 Bingo — First ball on the green\n📍 Bango — Closest to the pin once all balls are on the green\n🕳️ Bongo — First ball in the hole\n\nEach point is worth the dollar amount you set. Great equalizer — any skill level can grab points. Play in order of farthest from pin to keep it fair.`,
  },
  {
    emoji: '🐍',
    name: 'Snake',
    rules: `The last player to 3-putt holds the snake 🐍. You're stuck with it until someone else 3-putts — then it passes to them. Whoever holds the snake at the end of the round pays every other player the snake bet.\n\nNever 3-putt? Never touch the snake. 3-putt on 18? Ouch.`,
  },
  {
    emoji: '🎰',
    name: 'Vegas',
    rules: `A 2v2 team game where each team's scores combine into a 2-digit number. Lower team number wins the hole.\n\nThis app plays the popular action variant:\n• When either player makes par or better → lower digit goes first (4 and 6 = "46")\n• When BOTH players make bogey or worse → higher digit goes first (4 and 6 = "64")\n\nNote: The pure standard rule is simply lower digit always first — no bogey-flip. Use whichever your group agrees on before teeing off.\n\nDouble-digit scores (10+): the double-digit number always goes first regardless (scores of 4 and 10 = "104").\n\nPayout: difference between the two team numbers × your bet per point.\n\nFlip the Bird 🐦 (optional): birdie flips your opponent's digits ("47" → "74").\n\nHammer 🔨: either team can drop the Hammer mid-hole to double the stakes. Multipliers stack: ×1 → ×2 → ×4 → ×8.`,
  },
  {
    emoji: '⚔️',
    name: 'Best Ball',
    rules: `A 2v2 team game. All four players play their own ball every hole — but only the BEST (lowest) score on each hole counts for the team.\n\nStroke Play: Add up the best scores over 18 holes. Lower team total wins the full bet × stroke difference.\n\nMatch Play: Win holes outright with a lower team score. Most holes won takes the pot. Ties push.`,
  },
  {
    emoji: '🃏',
    name: 'Stableford',
    rules: `Points awarded per hole based on your score vs par:\n\n🌟 Albatross (3 under) = 5 points\n🦅 Eagle = 4 points\n🐦 Birdie = 3 points\n⛳ Par = 2 points\n👎 Bogey = 1 point\n💀 Double bogey or worse = 0 points\n\nHighest total points after 18 holes wins. Each losing player pays each winner your set dollar amount × the point difference.\n\nGreat equalizer — blow-up holes cap at 0 points. You can never go negative, so bad holes hurt less than in stroke play.`,
  },
  {
    emoji: '🐰',
    name: 'Rabbit',
    rules: `One rabbit, 18 holes, and a whole lot of pressure.\n\nThe first player to win a hole outright (lowest score, no ties) "catches the rabbit." They hold it until another player wins a hole outright — then the rabbit jumps to them.\n\nWhoever holds the rabbit at the end of the round COLLECTS from every other player. Catching the rabbit is good — holding it is better.\n\nIf nobody ever wins a hole outright, no payout. If you catch it on 17 and 18 is a tie — you're collecting.\n\nNote: This app plays simplified Rabbit — one bet over 18 holes. The traditional game runs two separate bets: front 9 and back 9, with the rabbit resetting at the turn. Either format works — agree before you tee off.`,
  },
  {
    emoji: '🗑️',
    name: 'Dots / Junk',
    rules: `Side bets rewarding great shots. Every dot you earn costs every other player your set dollar amount.\n\n🐦 Birdie — score 1 under par = 1 dot (auto-tracked)\n🦅 Eagle — score 2+ under par = 2 dots (auto-tracked)\n🏖️ Sandy — get up-and-down from a bunker (one shot out + finish the hole with par or better) = 1 dot (tap to mark in scorecard)\n🌿 Greenie — on par 3s only, tee shot must land on the green; closest to the pin who then makes par or better = 1 dot (tap to award in scorecard)\n\nYou can toggle which dot types are active when setting up the game. Mix with any other game — dots stack on top of everything else.`,
  },
  {
    emoji: '🔄',
    name: 'Sixes',
    rules: `A 4-player game where partners rotate every 6 holes — everyone plays with everyone.\n\nSegment 1 (Holes 1–6): Player 1 & 2 vs Player 3 & 4\nSegment 2 (Holes 7–12): Player 1 & 3 vs Player 2 & 4\nSegment 3 (Holes 13–18): Player 1 & 4 vs Player 2 & 3\n\nEach segment is match play — lowest score wins each hole. The team that wins the most holes in a segment collects from each opponent.\n\nTies within a segment push. No rotating partner drama — everyone partners up over the full round.`,
  },
  {
    emoji: '⚾',
    name: 'Nines',
    rules: `A 3-player game where 9 points are distributed every hole.\n\nBest score = 5 points. Second = 3 points. Worst = 1 point.\n\nTie rules:\n• Two tie for best: each gets 4 pts (5+3 split), worst gets 1\n• Two tie for worst: best gets 5 pts, each of the two gets 2 (3+1 split)\n• All tie: 3 pts each\n\nAt the end, players settle based on total point differences × your set dollar amount per point. A swing of 4 points (e.g., 5-1 hole) = 4× your bet.`,
  },
  {
    emoji: '🥃',
    name: 'Scotch',
    rules: `A 2v2 team points game. This app plays a simplified Low Ball / Low Total format — 5 points per hole.\n\n2 points — Low Ball: whichever team has the lower individual score wins 2 pts.\n3 points — Low Total: whichever team has the lower combined score wins 3 pts.\n\nA clean sweep wins all 5 pts on that hole. Ties on either category push (no points awarded).\n\nAt the end, point difference × your dollar amount determines the payout. Assign teams before teeing off.\n\nNote: Traditional 5-point Scotch (also called Umbriago) includes five separate categories — Low Ball, Low Total, Low Putts, Closest to Pin, and Birdie — worth 1 point each. This app plays a simplified 2-category version.`,
  },
  {
    emoji: '⛳',
    name: 'Closest to Pin',
    rules: `A par 3 side bet. On each par 3, whoever's tee shot comes to rest on the green closest to the pin collects from every other player.\n\nThe CTP winner is marked manually in the scorecard — tap the CTP panel, find the par 3 hole, and select the winner.\n\nKey rule: the ball must be on the green from the tee shot to qualify. A ball that misses the green is not eligible — even if it ends up closer than everyone else.\n\nSimple, clean, and sparks friendly competition on every par 3.`,
  },
  {
    emoji: '🎲',
    name: 'Aces & Deuces',
    rules: `Every hole, there's an Ace (best score) and a Deuce (worst score).\n\nThe Ace collects your set dollar amount from the Deuce. Players with middle scores push — no payment either way.\n\nTie rules (app variant): tied-best players all count as Aces; tied-worst all count as Deuces. All Aces collect from all Deuces.\n\nNote: The most common standard rule is that ties cancel — if two players tie for best, there's no Ace that hole (push). If two tie for worst, there's no Deuce. Agree on your group's tie rule before the round.\n\nIf everyone ties, it's always a push. Works great stacked alongside any other game.`,
  },
  {
    emoji: '⚖️',
    name: 'Quota',
    rules: `A personal points challenge layered on top of Stableford scoring.\n\nBefore the round, each player sets their quota — a target Stableford points total for 18 holes.\n\nStandard formula: Quota = 36 minus your course handicap\n(Scratch = 36 · 10-hdcp = 26 · 18-hdcp = 18 · 30-hdcp = 6)\n\nScoring (per hole):\n🌟 Albatross = 5 pts\n🦅 Eagle = 4 pts\n🐦 Birdie = 3 pts\n⛳ Par = 2 pts\n👎 Bogey = 1 pt\n💀 Double+ = 0 pts\n\nAt the end, each player's total is compared to their quota:\n• Beat your quota → collect (points over quota × your set dollar amount) from each player who missed theirs\n• Miss your quota → pay each player who beat theirs\n\nNote: Some groups use a birdie-heavy scale (Birdie = 4 pts, Eagle = 8 pts) to reward aggressive play. This app uses the traditional Stableford scale — agree on your scale before teeing off.\n\nGreat equalizer — different skill levels compete fairly because each player's quota is calibrated to their handicap.`,
  },
  {
    emoji: '😈',
    name: 'Trouble',
    rules: `Pay for your mistakes.\n\nBefore the round, agree which trouble categories are in play. When a player hits trouble, they pay every other player the set dollar amount — one charge per occurrence.\n\n😈 Trouble types:\n🚩 OB (out of bounds)\n💧 Water hazard\n3️⃣ 3-Putt\n🏖️ Sand trap\n🔍 Lost ball\n\nMultiple troubles on one hole stack — go OB and 3-putt on the same hole and you're paying twice.\n\nNote: This app pays each other player directly per occurrence (the action variant). Many groups play Trouble as a penalty pool — accumulate trouble points, and whoever finishes with the fewest pays everyone else. Agree on your format before the round.\n\nTrack trouble manually in the scorecard panel during your round.`,
  },
  {
    emoji: '🦁',
    name: 'Arnies',
    rules: `Named after Arnold Palmer — making par or better from off the fairway the ENTIRE hole.\n\nTo earn an Arnie, you must:\n1. Make par or better on the hole\n2. Never have your ball on the fairway at any point during the hole\n3. Be on a par-4 or par-5 — par-3s don't count (no fairway to miss)\n\nThat means playing from rough, trees, bunkers, or any non-fairway surface all the way to the green — and still making par. Even a ball that rolls through the edge of the fairway disqualifies. It's rare and impressive.\n\nWhen you pull it off, every other player pays you the set amount.\n\nNote: Standard Arnies use gross par. Some groups play net par (after handicap strokes) — agree before the round.\n\nMark Arnies manually in the scorecard panel. The chip is disabled on any hole where the player didn't make par or better.`,
  },
  {
    emoji: '🏦',
    name: 'Banker',
    rules: `One player is the Banker each hole — everyone else plays against them individually.\n\nAll other players compete against the Banker in stroke play, head-to-head:\n• Beat the Banker → Banker pays you the set amount\n• Lose to the Banker → you pay the Banker\n• Tie → push, no money changes hands\n\nThe Banker wins or loses against each opponent separately. A Banker with 3 opponents can collect or pay up to 3× per hole.\n\nStandard assignment rule: whoever won the previous hole (lowest score) becomes the next Banker. If the previous hole was tied, the current Banker retains the spot. The Banker always tees off last — opponents see their own shots before deciding whether to press.\n\nFirst hole: lowest handicap or coin flip.\n\nNote: This app uses a fixed bet amount and manual Banker assignment for simplicity. Traditional Banker lets each player set their own stake against the Banker within an agreed min/max range, adding a betting strategy layer. Also known as Chairman (UK) or Devil's Ball.`,
  },
  {
    emoji: '🔨',
    name: 'Hammer',
    rules: `A bet-doubling modifier that can be added to Nassau, Vegas, or other hole-based games. On any hole, any player (or team) can call "Hammer!" — doubling the value of that hole's bet.\n\nThe opponent must accept or concede:\n• Accept — the hole continues at the new doubled value. The receiving side can immediately re-Hammer back, doubling it again.\n• Concede — the hole is over. The hammering side wins at the previous (un-doubled) value.\n\nEither side can swing the Hammer at any point during a hole, and it can be thrown back and forth until someone concedes. Multipliers stack:\n×1 → ×2 → ×4 → ×8 → ×16\n\nIn this app, tap the ×N cell in the scorecard on any active hole, then pass the phone to call, accept, re-hammer, or concede.`,
  },
];

export default function RulesScreen() {
  const router = useRouter();
  const [expandedGame, setExpandedGame] = useState<string | null>(null);

  useEffect(() => {
    if (Platform.OS === 'android') {
      UIManager.setLayoutAnimationEnabledExperimental?.(true);
    }
  }, []);

  function toggle(name: string) {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setExpandedGame(prev => (prev === name ? null : name));
  }

  return (
    <ImageBackground
      source={require('../assets/bg.png')}
      style={styles.bgFull}
      resizeMode="cover"
    >
      <View style={styles.bgOverlay} />

      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} activeOpacity={0.7}>
          <Text style={styles.backBtn}>← Rules</Text>
        </TouchableOpacity>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        {GAMES.map((game, index) => (
          <View key={game.name} style={styles.card}>
            <TouchableOpacity onPress={() => toggle(game.name)} activeOpacity={0.75}>
              <View style={styles.rowHeader}>
                <Text style={styles.number}>{index + 1}</Text>
                <Text style={styles.emoji}>{game.emoji}</Text>
                <Text style={styles.name}>{game.name}</Text>
                <Text style={styles.chevron}>
                  {expandedGame === game.name ? '▾' : '▸'}
                </Text>
              </View>
              {expandedGame === game.name && (
                <View style={styles.rulesBody}>
                  <Text style={styles.rulesText}>{game.rules}</Text>
                </View>
              )}
            </TouchableOpacity>
          </View>
        ))}
      </ScrollView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  bgFull: { flex: 1, width: '100%' },
  bgOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.62)',
  },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  backBtn: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  scroll: { flex: 1, width: '100%' },
  content: {
    flexGrow: 1,
    width: '100%',
    paddingHorizontal: 20,
    paddingBottom: 48,
  },
  card: {
    backgroundColor: '#161616',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#222',
    marginBottom: 10,
    overflow: 'hidden',
  },
  rowHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 16,
  },
  number: {
    fontSize: 13,
    fontWeight: '700',
    color: '#444',
    width: 20,
    marginRight: 8,
    textAlign: 'right',
  },
  emoji: {
    fontSize: 28,
    marginRight: 12,
  },
  name: {
    flex: 1,
    fontSize: 17,
    fontWeight: '700',
    color: '#fff',
  },
  chevron: {
    fontSize: 16,
    color: '#39FF14',
    fontWeight: '600',
  },
  rulesBody: {
    paddingHorizontal: 16,
    paddingBottom: 16,
    paddingTop: 4,
  },
  rulesText: {
    fontSize: 14,
    lineHeight: 21,
    color: '#aaa',
  },
});
