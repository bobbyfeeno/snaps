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
    emoji: '📋',
    name: 'Keep Score',
    rules: `Standard golf scorecard. Track every player's score hole-by-hole with no side bets attached. Combine it with any other game mode for a full picture of the round.`,
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
        {GAMES.map(game => (
          <View key={game.name} style={styles.card}>
            <TouchableOpacity onPress={() => toggle(game.name)} activeOpacity={0.75}>
              <View style={styles.rowHeader}>
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
