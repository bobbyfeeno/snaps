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
    rules: `Three bets in one: Front 9, Back 9, and Full 18. The player with the lowest score on each segment wins that bet.\n\nStroke Play: Total strokes decide the winner.\nMatch Play: Win holes one at a time — whoever wins the most holes takes the bet.\n\nAuto-Press: When a player goes 2-down, a new side bet automatically kicks in for the remaining holes. Presses can stack.`,
  },
  {
    emoji: '🎰',
    name: 'Skins',
    rules: `Each hole is worth a skin (dollar amount you set). Lowest score on a hole wins the skin outright — but only if nobody ties. Ties roll the skin over to the next hole, letting the pot grow. A skin worth 5× what you started with is where legends are made.`,
  },
  {
    emoji: '🐺',
    name: 'Wolf',
    rules: `One player is the "Wolf" each hole (rotating each hole). The Wolf watches each opponent tee off one at a time, deciding after each shot whether to pick that player as a partner — or pass. Once you pass, you can't go back.\n\nLone Wolf: If the Wolf passes everyone, they go 1 vs. 3 for double the bet.\nPartner Wolf: The chosen duo plays against the other two for the set bet amount.`,
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
    rules: `A 2v2 team game with a twist: each team's scores are concatenated into a 2-digit number.\n\nScoring: When either player makes par or better, the lower digit goes first (e.g., 3 and 5 = "35"). On bogey or worse, the higher digit goes first (e.g., 5 and 3 = "53"). Lower team number wins the hole.\n\nPayout: The difference between the two team numbers × your bet per point.\n\nFlip the Bird 🐦: If you make birdie, you flip your opponent's digits (their "47" becomes "74").\n\nHammer 🔨: Either team can drop the Hammer mid-hole to double the stakes. Multipliers stack: ×1 → ×2 → ×4 → ×8.`,
  },
  {
    emoji: '⚔️',
    name: 'Best Ball',
    rules: `A 2v2 team game. All four players play their own ball every hole — but only the BEST (lowest) score on each hole counts for the team.\n\nStroke Play: Add up the best scores over 18 holes. Lower team total wins the full bet × stroke difference.\n\nMatch Play: Win holes outright with a lower team score. Most holes won takes the pot. Ties push.`,
  },
  {
    emoji: '🃏',
    name: 'Stableford',
    rules: `Points awarded per hole based on your score vs par:\n\n🦅 Eagle or better = 4 points\n🐦 Birdie = 3 points\n⛳ Par = 2 points\n👎 Bogey = 1 point\n💀 Double bogey or worse = 0 points\n\nHighest total points after 18 holes wins. Each losing player pays each winner your set dollar amount × the point difference.\n\nGreat equalizer — even a bad hole only costs you 2 points instead of blowing up a stroke total.`,
  },
  {
    emoji: '🐰',
    name: 'Rabbit',
    rules: `One rabbit, 18 holes, and a whole lot of pressure.\n\nThe first player to win a hole outright (lowest score, no ties) "catches the rabbit." They hold it until another player wins a hole outright — then the rabbit jumps to them.\n\nWhoever holds the rabbit at the end of the round COLLECTS from every other player. Catching the rabbit is good — holding it is better.\n\nIf nobody ever wins a hole outright, no payout. If you catch it on 17 and 18 is a tie — you're collecting.`,
  },
  {
    emoji: '🗑️',
    name: 'Dots / Junk',
    rules: `Side bets rewarding great shots. Every dot you earn costs every other player your set dollar amount.\n\n🐦 Birdie — score 1 under par = 1 dot (auto-tracked)\n🦅 Eagle — score 2+ under par = 2 dots (auto-tracked)\n🏖️ Sandy — make par or better after hitting from a bunker = 1 dot (tap to mark in scorecard)\n🌿 Greenie — on par 3s only, closest player to the pin who makes par or better = 1 dot (tap to award in scorecard)\n\nYou can toggle which dot types are active when setting up the game. Mix with any other game — dots stack on top of everything else.`,
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
    rules: `A 2v2 team game worth 5 points per hole.\n\n2 points — Low Ball: whichever team has the better individual score wins 2 pts.\n3 points — Low Total: whichever team has the lower combined score wins 3 pts.\n\nA clean sweep (win both low ball and low total) wins all 5 pts on that hole.\n\nAt the end, the point difference × your dollar amount determines the payout. Assign teams before the round starts.`,
  },
  {
    emoji: '⛳',
    name: 'Closest to Pin',
    rules: `A par 3 side bet. On each par 3, whoever finishes closest to the pin collects from every other player.\n\nThe CTP winner is marked manually in the scorecard — tap the CTP panel, find the par 3 hole, and select the winner.\n\nNo score requirement — just closest to the stick when everyone is on (or near) the green. Simple, clean, and sparks friendly competition on every par 3.`,
  },
  {
    emoji: '🎲',
    name: 'Aces & Deuces',
    rules: `Every hole, there's an Ace (best score) and a Deuce (worst score).\n\nThe Ace collects your set dollar amount from the Deuce. Players with middle scores push — no payment either way.\n\nTie rules: if two players tie for best, both are Aces. If two tie for worst, both are Deuces. All Aces collect from all Deuces.\n\nIf everyone ties, it's a push. Works great stacked alongside any other game.`,
  },
  {
    emoji: '🔨',
    name: 'Hammer',
    rules: `A bet-doubling modifier applied to Nassau or Vegas. On any hole, any player can call "Hammer!" — doubling the value of that hole's bet. The opponent must accept or concede.\n\nMultipliers stack each time the Hammer is called:\n×1 → ×2 → ×4 → ×8\n\nTap the ×N cell in the scorecard to cycle the multiplier for that hole.`,
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
