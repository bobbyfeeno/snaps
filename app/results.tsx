import { useRouter } from 'expo-router';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { GameMode, GameResult, LeaderboardEntry, Payout } from '../types';
import { multiGameResults, resetGameResults } from './scores';
import { gameSetup, resetGameSetup } from './setup';

function formatMoney(n: number) {
  if (n === 0) return '$0';
  return n % 1 === 0 ? `$${n}` : `$${n.toFixed(2)}`;
}

function getGameEmoji(mode: GameMode): string {
  switch (mode) {
    case 'taxman': return '💰';
    case 'nassau': return '🏌️';
    case 'skins': return '🎰';
    case 'wolf': return '🐺';
    case 'bingo-bango-bongo': return '🎯';
    case 'snake': return '🐍';
    case 'scorecard': return '📋';
    default: return '🎮';
  }
}

export default function ResultsScreen() {
  const router = useRouter();
  const results = multiGameResults;
  const setup = gameSetup;

  if (!results || !setup) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>No results found.</Text>
        <TouchableOpacity onPress={() => router.replace('/')}>
          <Text style={styles.errorLink}>← Home</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // Calculate summary stats
  const totalPot = results.games.reduce((sum, game) => {
    return sum + game.payouts.reduce((ps, p) => ps + p.amount, 0);
  }, 0);

  const winners = Object.entries(results.combinedNet).filter(([_, n]) => n > 0);
  const losers = Object.entries(results.combinedNet).filter(([_, n]) => n < 0);

  // Sort combined net for display
  const sortedNet = Object.entries(results.combinedNet).sort((a, b) => b[1] - a[1]);

  return (
    <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
      {/* Summary banner */}
      <View style={styles.summaryBanner}>
        <View style={styles.summaryItem}>
          <Text style={styles.summaryNum}>{winners.length}</Text>
          <Text style={styles.summaryLabel}>Winner{winners.length !== 1 ? 's' : ''}</Text>
        </View>
        <View style={styles.summaryDivider} />
        <View style={styles.summaryItem}>
          <Text style={styles.summaryNum}>{losers.length}</Text>
          <Text style={styles.summaryLabel}>Loser{losers.length !== 1 ? 's' : ''}</Text>
        </View>
        <View style={styles.summaryDivider} />
        <View style={styles.summaryItem}>
          <Text style={styles.summaryNum}>{formatMoney(totalPot / 2)}</Text>
          <Text style={styles.summaryLabel}>Total Pot</Text>
        </View>
      </View>

      {/* Active games indicator */}
      <View style={styles.gamesBar}>
        {results.games.map(g => (
          <View key={g.mode} style={styles.gameChip}>
            <Text style={styles.gameChipText}>{getGameEmoji(g.mode)} {g.label}</Text>
          </View>
        ))}
      </View>

      {/* Per-game results */}
      {results.games.map((game, idx) => (
        <GameResultSection key={game.mode} game={game} isLast={idx === results.games.length - 1} />
      ))}

      {/* Combined Net Totals */}
      {results.games.length > 1 && (
        <>
          <Text style={[styles.sectionLabel, { marginTop: 28 }]}>Combined Net Totals</Text>
          <Text style={styles.sectionHint}>All games combined</Text>
          {sortedNet.map(([name, amount]) => (
            <View key={name} style={styles.totalRow}>
              <Text style={styles.totalName}>{name}</Text>
              <Text style={[styles.totalAmount, amount >= 0 ? styles.totalPos : styles.totalNeg]}>
                {amount >= 0 ? '+' : ''}{formatMoney(amount)}
              </Text>
            </View>
          ))}
        </>
      )}

      {/* If only one game, show net totals for that game */}
      {results.games.length === 1 && (
        <>
          <Text style={[styles.sectionLabel, { marginTop: 28 }]}>Net Totals</Text>
          {sortedNet.map(([name, amount]) => (
            <View key={name} style={styles.totalRow}>
              <Text style={styles.totalName}>{name}</Text>
              <Text style={[styles.totalAmount, amount >= 0 ? styles.totalPos : styles.totalNeg]}>
                {amount >= 0 ? '+' : ''}{formatMoney(amount)}
              </Text>
            </View>
          ))}
        </>
      )}

      {/* Actions */}
      <TouchableOpacity
        style={styles.newGameBtn}
        onPress={() => {
          resetGameResults();
          resetGameSetup();
          router.replace('/setup');
        }}
        activeOpacity={0.8}
      >
        <Text style={styles.newGameBtnText}>Play Again</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.homeBtn}
        onPress={() => {
          resetGameResults();
          resetGameSetup();
          router.replace('/');
        }}
        activeOpacity={0.7}
      >
        <Text style={styles.homeBtnText}>← Home</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

// ─── Per-game result section ────────────────────────────────────────────────

function GameResultSection({ game, isLast }: { game: GameResult; isLast: boolean }) {
  const hasPayouts = game.payouts.length > 0;
  const sortedNet = Object.entries(game.net).sort((a, b) => b[1] - a[1]);
  const isScorecard = game.mode === 'scorecard';

  return (
    <View style={[styles.gameSection, !isLast && styles.gameSectionBorder]}>
      <View style={styles.gameSectionHeader}>
        <Text style={styles.gameSectionTitle}>
          {getGameEmoji(game.mode)} {game.label}
        </Text>
      </View>

      {/* Scorecard: show leaderboard instead of net standings */}
      {isScorecard && game.leaderboard ? (
        <View style={styles.leaderboardList}>
          {game.leaderboard.map((entry, idx) => (
            <View key={entry.name} style={styles.leaderboardRow}>
              <Text style={[styles.leaderboardRank, idx === 0 && styles.leaderboardRankFirst]}>
                {entry.rank}
              </Text>
              <Text style={[styles.leaderboardName, idx === 0 && styles.leaderboardNameFirst]}>
                {entry.name}
              </Text>
              <Text style={[styles.leaderboardScore, idx === 0 && styles.leaderboardScoreFirst]}>
                {entry.total}
              </Text>
            </View>
          ))}
        </View>
      ) : (
        <>
          {/* Net standings for this game */}
          <View style={styles.gameNetList}>
            {sortedNet.map(([name, amount]) => (
              <View key={name} style={styles.gameNetRow}>
                <Text style={styles.gameNetName}>{name}</Text>
                <View style={[styles.gameNetBadge, amount >= 0 ? styles.gameNetBadgePos : styles.gameNetBadgeNeg]}>
                  <Text style={styles.gameNetText}>
                    {amount >= 0 ? '+' : ''}{formatMoney(amount)}
                  </Text>
                </View>
              </View>
            ))}
          </View>

          {/* Payouts for this game */}
          {hasPayouts ? (
            <View style={styles.payoutsContainer}>
              <Text style={styles.payoutsLabel}>Payouts</Text>
              {consolidatePayouts(game.payouts).map((p, i) => (
                <View key={i} style={styles.payoutRow}>
                  <Text style={styles.payoutFrom}>{p.from}</Text>
                  <View style={styles.payoutArrowContainer}>
                    <View style={styles.payoutLine} />
                    <Text style={styles.payoutAmount}>{formatMoney(p.amount)}</Text>
                    <View style={styles.payoutLine} />
                    <Text style={styles.payoutArrow}>→</Text>
                  </View>
                  <Text style={styles.payoutTo}>{p.to}</Text>
                </View>
              ))}
            </View>
          ) : (
            <View style={styles.noPayoutsCard}>
              <Text style={styles.noPayoutsText}>No payouts for this game</Text>
            </View>
          )}
        </>
      )}
    </View>
  );
}

// Consolidate multiple payouts between same players
function consolidatePayouts(payouts: Payout[]): Payout[] {
  const map = new Map<string, Payout>();
  
  for (const p of payouts) {
    const key = `${p.from}→${p.to}`;
    const existing = map.get(key);
    if (existing) {
      existing.amount += p.amount;
    } else {
      map.set(key, { ...p });
    }
  }
  
  return Array.from(map.values());
}

const styles = StyleSheet.create({
  scroll: { flex: 1, backgroundColor: '#0d1f0d' },
  content: { padding: 20, paddingBottom: 48 },

  errorContainer: { flex: 1, backgroundColor: '#0d1f0d', alignItems: 'center', justifyContent: 'center' },
  errorText: { color: '#ff5555', fontSize: 18, marginBottom: 16 },
  errorLink: { color: '#39FF14', fontSize: 16 },

  summaryBanner: {
    flexDirection: 'row',
    backgroundColor: '#162416',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    paddingVertical: 20,
    marginBottom: 16,
  },
  summaryItem: { flex: 1, alignItems: 'center' },
  summaryNum: { fontSize: 28, fontWeight: '800', color: '#39FF14' },
  summaryLabel: { fontSize: 12, color: '#5a8a5a', marginTop: 2, textTransform: 'uppercase', letterSpacing: 0.5 },
  summaryDivider: { width: 1, backgroundColor: '#2a4a2a', marginVertical: 8 },

  gamesBar: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 20,
  },
  gameChip: {
    backgroundColor: '#1a2a1a',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: '#2a4a2a',
  },
  gameChipText: {
    color: '#88bb88',
    fontSize: 12,
    fontWeight: '600',
  },

  // Per-game sections
  gameSection: {
    marginBottom: 20,
  },
  gameSectionBorder: {
    paddingBottom: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#2a4a2a',
  },
  gameSectionHeader: {
    marginBottom: 12,
  },
  gameSectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#39FF14',
  },

  gameNetList: {
    marginBottom: 12,
  },
  gameNetRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: '#162416',
    borderRadius: 10,
    marginBottom: 6,
    borderWidth: 1,
    borderColor: '#2a4a2a',
  },
  gameNetName: {
    fontSize: 15,
    fontWeight: '600',
    color: '#fff',
  },
  gameNetBadge: {
    borderRadius: 6,
    paddingHorizontal: 10,
    paddingVertical: 4,
    minWidth: 60,
    alignItems: 'center',
  },
  gameNetBadgePos: { backgroundColor: '#1a3d1a' },
  gameNetBadgeNeg: { backgroundColor: '#3d1a1a' },
  gameNetText: {
    fontSize: 14,
    fontWeight: '700',
    color: '#fff',
  },

  // Scorecard leaderboard
  leaderboardList: {
    marginBottom: 12,
  },
  leaderboardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
    backgroundColor: '#162416',
    borderRadius: 10,
    marginBottom: 6,
    borderWidth: 1,
    borderColor: '#2a4a2a',
  },
  leaderboardRank: {
    fontSize: 16,
    fontWeight: '700',
    color: '#888',
    width: 28,
  },
  leaderboardRankFirst: {
    color: '#39FF14',
  },
  leaderboardName: {
    flex: 1,
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
  leaderboardNameFirst: {
    color: '#39FF14',
  },
  leaderboardScore: {
    fontSize: 18,
    fontWeight: '700',
    color: '#fff',
    minWidth: 40,
    textAlign: 'right',
  },
  leaderboardScoreFirst: {
    color: '#39FF14',
  },

  payoutsContainer: {
    marginTop: 8,
  },
  payoutsLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#5a8a5a',
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  payoutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#0f1f0f',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#1a2a1a',
    padding: 12,
    marginBottom: 6,
  },
  payoutFrom: { fontSize: 14, fontWeight: '700', color: '#ff6666', flex: 1 },
  payoutArrowContainer: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8, flex: 1.4, justifyContent: 'center' },
  payoutLine: { height: 1, flex: 1, backgroundColor: '#2a4a2a' },
  payoutAmount: { fontSize: 14, fontWeight: '800', color: '#fff', marginHorizontal: 6 },
  payoutArrow: { fontSize: 14, color: '#39FF14', marginLeft: 2 },
  payoutTo: { fontSize: 14, fontWeight: '700', color: '#39FF14', flex: 1, textAlign: 'right' },

  noPayoutsCard: {
    backgroundColor: '#0f1f0f',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#1a2a1a',
    padding: 14,
    alignItems: 'center',
  },
  noPayoutsText: { fontSize: 13, color: '#5a8a5a', textAlign: 'center' },

  sectionLabel: { fontSize: 18, fontWeight: '700', color: '#39FF14', marginBottom: 4 },
  sectionHint: { fontSize: 12, color: '#5a8a5a', marginBottom: 12 },

  totalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 4,
    borderBottomWidth: 1,
    borderBottomColor: '#1e3a1e',
  },
  totalName: { fontSize: 17, color: '#fff', fontWeight: '600' },
  totalAmount: { fontSize: 22, fontWeight: '800' },
  totalPos: { color: '#39FF14' },
  totalNeg: { color: '#ff6666' },

  newGameBtn: {
    backgroundColor: '#39FF14',
    borderRadius: 16,
    paddingVertical: 20,
    alignItems: 'center',
    marginTop: 32,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  newGameBtnText: { fontSize: 20, fontWeight: '800', color: '#000' },

  homeBtn: {
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 12,
  },
  homeBtnText: { fontSize: 16, color: '#5a8a5a' },
});
