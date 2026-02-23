import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { BevelCard } from '../components/BevelCard';
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
      {/* Top-center glow overlay */}
      <View pointerEvents="none" style={styles.topGlow} />

      {/* Summary banner */}
      <BevelCard style={styles.summaryBanner}>
        <View style={styles.summaryBannerInner}>
          <View style={styles.summaryItem}>
            <Text style={styles.summaryNum}>{winners.length}</Text>
            <Text style={styles.summaryLabel}>WINNER{winners.length !== 1 ? 'S' : ''}</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Text style={styles.summaryNum}>{losers.length}</Text>
            <Text style={styles.summaryLabel}>LOSER{losers.length !== 1 ? 'S' : ''}</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Text style={styles.summaryNum}>{formatMoney(totalPot / 2)}</Text>
            <Text style={styles.summaryLabel}>TOTAL POT</Text>
          </View>
        </View>
      </BevelCard>

      {/* Active games indicator */}
      <View style={styles.gamesBar}>
        {results.games.map(g => (
          <LinearGradient key={g.mode} colors={['#1a1a1a', '#111111']} style={styles.gameChip}>
            <Text style={styles.gameChipText}>{getGameEmoji(g.mode)} {g.label}</Text>
          </LinearGradient>
        ))}
      </View>

      {/* Per-game results */}
      {results.games.map((game, idx) => (
        <GameResultSection key={game.mode} game={game} isLast={idx === results.games.length - 1} />
      ))}

      {/* Combined Net Totals */}
      {results.games.length > 1 && (
        <>
          <BevelCard style={styles.sectionHeader}>
            <View style={styles.sectionHeaderInner}>
              <Text style={styles.sectionLabel}>Combined Net Totals</Text>
              <Text style={styles.sectionHint}>All games combined</Text>
            </View>
          </BevelCard>
          {sortedNet.map(([name, amount]) => {
            const isWinner = amount > 0;
            const isLoser = amount < 0;
            return isWinner ? (
              <LinearGradient 
                key={name} 
                colors={['#1e2e12', '#131f0c', '#0b1507']} 
                locations={[0, 0.5, 1]}
                style={[styles.totalRow, styles.totalRowWinner]}
              >
                <View style={styles.rowEdgeTop} />
                <Text style={styles.totalName}>{name}</Text>
                <Text style={[styles.totalAmount, styles.totalPos]}>
                  +{formatMoney(amount)}
                </Text>
              </LinearGradient>
            ) : isLoser ? (
              <LinearGradient 
                key={name} 
                colors={['#2a0808', '#180505', '#100404']} 
                locations={[0, 0.5, 1]}
                style={[styles.totalRow, styles.totalRowLoser]}
              >
                <View style={styles.rowEdgeTop} />
                <Text style={styles.totalName}>{name}</Text>
                <Text style={[styles.totalAmount, styles.totalNeg]}>
                  {formatMoney(amount)}
                </Text>
              </LinearGradient>
            ) : (
              <LinearGradient 
                key={name} 
                colors={['#262626', '#1a1a1a', '#101010']} 
                locations={[0, 0.5, 1]}
                style={styles.totalRow}
              >
                <View style={styles.rowEdgeTop} />
                <Text style={styles.totalName}>{name}</Text>
                <Text style={[styles.totalAmount, { color: '#888' }]}>
                  {formatMoney(amount)}
                </Text>
              </LinearGradient>
            );
          })}
        </>
      )}

      {/* If only one game, show net totals for that game */}
      {results.games.length === 1 && (
        <>
          <BevelCard style={styles.sectionHeader}>
            <View style={styles.sectionHeaderInner}>
              <Text style={styles.sectionLabel}>Net Totals</Text>
            </View>
          </BevelCard>
          {sortedNet.map(([name, amount]) => {
            const isWinner = amount > 0;
            const isLoser = amount < 0;
            return isWinner ? (
              <LinearGradient 
                key={name} 
                colors={['#1e2e12', '#131f0c', '#0b1507']} 
                locations={[0, 0.5, 1]}
                style={[styles.totalRow, styles.totalRowWinner]}
              >
                <View style={styles.rowEdgeTop} />
                <Text style={styles.totalName}>{name}</Text>
                <Text style={[styles.totalAmount, styles.totalPos]}>
                  +{formatMoney(amount)}
                </Text>
              </LinearGradient>
            ) : isLoser ? (
              <LinearGradient 
                key={name} 
                colors={['#2a0808', '#180505', '#100404']} 
                locations={[0, 0.5, 1]}
                style={[styles.totalRow, styles.totalRowLoser]}
              >
                <View style={styles.rowEdgeTop} />
                <Text style={styles.totalName}>{name}</Text>
                <Text style={[styles.totalAmount, styles.totalNeg]}>
                  {formatMoney(amount)}
                </Text>
              </LinearGradient>
            ) : (
              <LinearGradient 
                key={name} 
                colors={['#262626', '#1a1a1a', '#101010']} 
                locations={[0, 0.5, 1]}
                style={styles.totalRow}
              >
                <View style={styles.rowEdgeTop} />
                <Text style={styles.totalName}>{name}</Text>
                <Text style={[styles.totalAmount, { color: '#888' }]}>
                  {formatMoney(amount)}
                </Text>
              </LinearGradient>
            );
          })}
        </>
      )}

      {/* Actions */}
      <View style={styles.playAgainOuter}>
        <TouchableOpacity
          activeOpacity={0.85}
          onPress={() => {
            resetGameResults();
            resetGameSetup();
            router.replace('/setup');
          }}
        >
          <LinearGradient
            colors={['#52ff20', '#2dcc08', '#1fa005']}
            locations={[0, 0.6, 1]}
            start={{ x: 0.5, y: 0 }}
            end={{ x: 0.5, y: 1 }}
            style={styles.playAgainGrad}
          >
            <View style={styles.btnSpecular} />
            <View style={styles.btnEdgeTop} />
            <View style={styles.btnEdgeBottom} />
            <Text style={styles.playAgainText}>Play Again</Text>
          </LinearGradient>
        </TouchableOpacity>
      </View>

      <TouchableOpacity
        activeOpacity={0.7}
        onPress={() => {
          resetGameResults();
          resetGameSetup();
          router.replace('/');
        }}
      >
        <LinearGradient colors={['#1e1e1e', '#141414']} style={styles.homeBtn}>
          <View style={styles.cardHighlight} />
          <Text style={styles.homeBtnText}>← Home</Text>
        </LinearGradient>
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
      <LinearGradient colors={['#1a1a1a', '#111111']} style={styles.gameSectionHeader}>
        <View style={styles.cardHighlight} />
        <Text style={styles.gameSectionTitle}>
          {getGameEmoji(game.mode)} {game.label}
        </Text>
      </LinearGradient>

      {/* Scorecard: show leaderboard instead of net standings */}
      {isScorecard && game.leaderboard ? (
        <View style={styles.leaderboardList}>
          {game.leaderboard.map((entry, idx) => (
            idx === 0 ? (
              <LinearGradient 
                key={entry.name} 
                colors={['#172210', '#0d1508']} 
                style={[styles.leaderboardRow, styles.leaderboardRowFirst]}
              >
                <Text style={[styles.leaderboardRank, styles.leaderboardRankFirst]}>
                  {entry.rank}
                </Text>
                <Text style={[styles.leaderboardName, styles.leaderboardNameFirst]}>
                  {entry.name}
                </Text>
                <Text style={[styles.leaderboardScore, styles.leaderboardScoreFirst]}>
                  {entry.total}
                </Text>
              </LinearGradient>
            ) : (
              <LinearGradient 
                key={entry.name} 
                colors={['#1c1c1c', '#121212']} 
                style={styles.leaderboardRow}
              >
                <View style={styles.cardHighlight} />
                <Text style={styles.leaderboardRank}>{entry.rank}</Text>
                <Text style={styles.leaderboardName}>{entry.name}</Text>
                <Text style={styles.leaderboardScore}>{entry.total}</Text>
              </LinearGradient>
            )
          ))}
        </View>
      ) : (
        <>
          {/* Net standings for this game */}
          <View style={styles.gameNetList}>
            {sortedNet.map(([name, amount]) => (
              <LinearGradient 
                key={name} 
                colors={['#1c1c1c', '#121212']} 
                style={styles.gameNetRow}
              >
                <View style={styles.cardHighlight} />
                <Text style={styles.gameNetName}>{name}</Text>
                {amount >= 0 ? (
                  <LinearGradient 
                    colors={['#1a3a0a', '#0f2006']} 
                    style={[styles.gameNetBadge, styles.gameNetBadgePos]}
                  >
                    <Text style={[styles.gameNetText, styles.gameNetTextPos]}>
                      +{formatMoney(amount)}
                    </Text>
                  </LinearGradient>
                ) : (
                  <LinearGradient 
                    colors={['#3a0a0a', '#200606']} 
                    style={[styles.gameNetBadge, styles.gameNetBadgeNeg]}
                  >
                    <Text style={[styles.gameNetText, styles.gameNetTextNeg]}>
                      {formatMoney(amount)}
                    </Text>
                  </LinearGradient>
                )}
              </LinearGradient>
            ))}
          </View>

          {/* Payouts for this game */}
          {hasPayouts ? (
            <View style={styles.payoutsContainer}>
              <Text style={styles.payoutsLabel}>PAYOUTS</Text>
              {consolidatePayouts(game.payouts).map((p, i) => (
                <LinearGradient 
                  key={i} 
                  colors={['#1c1c1c', '#121212']} 
                  style={styles.payoutRow}
                >
                  <View style={styles.cardHighlight} />
                  <Text style={styles.payoutFrom}>{p.from}</Text>
                  <View style={styles.payoutArrowContainer}>
                    <View style={styles.payoutLine} />
                    <Text style={styles.payoutAmount}>{formatMoney(p.amount)}</Text>
                    <View style={styles.payoutLine} />
                    <Text style={styles.payoutArrow}>→</Text>
                  </View>
                  <Text style={styles.payoutTo}>{p.to}</Text>
                </LinearGradient>
              ))}
            </View>
          ) : (
            <LinearGradient colors={['#1c1c1c', '#121212']} style={styles.noPayoutsCard}>
              <View style={styles.cardHighlight} />
              <Text style={styles.noPayoutsText}>No payouts for this game</Text>
            </LinearGradient>
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
  scroll: { flex: 1, backgroundColor: '#050505' },
  content: { padding: 20, paddingBottom: 48 },

  topGlow: {
    position: 'absolute',
    width: 500,
    height: 500,
    borderRadius: 250,
    backgroundColor: '#39FF14',
    opacity: 0.025,
    top: -50,
    alignSelf: 'center',
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 1,
    shadowRadius: 120,
  },

  errorContainer: { flex: 1, backgroundColor: '#050505', alignItems: 'center', justifyContent: 'center' },
  errorText: { color: '#ff4444', fontSize: 18, marginBottom: 16 },
  errorLink: { color: '#39FF14', fontSize: 16 },

  cardHighlight: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.07)',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
  },
  
  // Button bevel styles
  btnSpecular: {
    position: 'absolute',
    top: 3,
    left: '15%',
    right: '15%',
    height: 8,
    backgroundColor: 'rgba(255,255,255,0.25)',
    borderRadius: 8,
  },
  btnEdgeTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.4)',
    borderTopLeftRadius: 14,
    borderTopRightRadius: 14,
  },
  btnEdgeBottom: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(0,0,0,0.35)',
    borderBottomLeftRadius: 14,
    borderBottomRightRadius: 14,
  },
  
  // Row edge bevel
  rowEdgeTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.10)',
    borderTopLeftRadius: 10,
    borderTopRightRadius: 10,
  },

  summaryBanner: {
    marginBottom: 16,
  },
  summaryBannerInner: {
    flexDirection: 'row',
    paddingVertical: 20,
  },
  summaryItem: { flex: 1, alignItems: 'center' },
  summaryNum: { fontSize: 28, fontWeight: '800', color: '#39FF14' },
  summaryLabel: { 
    fontSize: 11, 
    color: '#555', 
    marginTop: 2, 
    textTransform: 'uppercase', 
    letterSpacing: 1.5 
  },
  summaryDivider: { width: 1, backgroundColor: '#242424', marginVertical: 8 },

  gamesBar: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 20,
  },
  gameChip: {
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: '#242424',
  },
  gameChipText: {
    color: '#888',
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
    borderBottomColor: '#242424',
  },
  gameSectionHeader: {
    marginBottom: 12,
    borderRadius: 12,
    padding: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 12,
    elevation: 8,
    overflow: 'hidden',
  },
  gameSectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#fff',
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
    borderRadius: 10,
    marginBottom: 6,
    borderWidth: 1,
    borderColor: '#242424',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 12,
    elevation: 8,
    overflow: 'hidden',
  },
  gameNetName: {
    fontSize: 15,
    fontWeight: '600',
    color: '#fff',
  },
  gameNetBadge: {
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 4,
    minWidth: 70,
    alignItems: 'center',
    borderWidth: 1,
  },
  gameNetBadgePos: { 
    borderColor: '#39FF14',
    shadowColor: '#39FF14',
    shadowOpacity: 0.4,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 0 },
  },
  gameNetBadgeNeg: { 
    borderColor: '#ff4444',
  },
  gameNetText: {
    fontSize: 14,
    fontWeight: '800',
  },
  gameNetTextPos: { color: '#39FF14' },
  gameNetTextNeg: { color: '#ff4444' },

  // Scorecard leaderboard
  leaderboardList: {
    marginBottom: 12,
  },
  leaderboardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 10,
    marginBottom: 6,
    borderWidth: 1,
    borderColor: '#242424',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 12,
    elevation: 8,
    overflow: 'hidden',
  },
  leaderboardRowFirst: {
    borderLeftWidth: 3,
    borderLeftColor: '#39FF14',
    shadowColor: '#39FF14',
    shadowOffset: { width: -2, height: 0 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
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
    color: '#fff',
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
    fontSize: 11,
    fontWeight: '700',
    color: '#666',
    marginBottom: 8,
    textTransform: 'uppercase',
    letterSpacing: 1.5,
  },
  payoutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#242424',
    padding: 12,
    marginBottom: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 12,
    elevation: 8,
    overflow: 'hidden',
  },
  payoutFrom: { fontSize: 14, fontWeight: '700', color: '#ff4444', flex: 1 },
  payoutArrowContainer: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8, flex: 1.4, justifyContent: 'center' },
  payoutLine: { height: 1, flex: 1, backgroundColor: '#242424' },
  payoutAmount: { fontSize: 14, fontWeight: '800', color: '#fff', marginHorizontal: 6 },
  payoutArrow: { fontSize: 14, color: '#39FF14', marginLeft: 2 },
  payoutTo: { fontSize: 14, fontWeight: '700', color: '#39FF14', flex: 1, textAlign: 'right' },

  noPayoutsCard: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#242424',
    padding: 14,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 12,
    elevation: 8,
    overflow: 'hidden',
  },
  noPayoutsText: { fontSize: 13, color: '#555', textAlign: 'center' },

  sectionHeader: {
    marginTop: 28,
    marginBottom: 12,
  },
  sectionHeaderInner: {
    padding: 12,
  },
  sectionLabel: { fontSize: 22, fontWeight: '700', color: '#fff', marginBottom: 4 },
  sectionHint: { fontSize: 13, color: '#888' },

  totalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 12,
    marginBottom: 8,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#1e1e1e',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.7,
    shadowRadius: 16,
    elevation: 12,
    overflow: 'hidden',
    position: 'relative',
  },
  totalRowWinner: {
    borderLeftWidth: 3,
    borderLeftColor: '#39FF14',
    shadowColor: '#39FF14',
    shadowOffset: { width: -2, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
  },
  totalRowLoser: {
    borderLeftWidth: 3,
    borderLeftColor: '#ff4444',
  },
  totalName: { fontSize: 17, color: '#fff', fontWeight: '600' },
  totalAmount: { fontSize: 22, fontWeight: '800' },
  totalPos: { color: '#39FF14' },
  totalNeg: { color: '#ff4444' },

  playAgainOuter: {
    borderRadius: 14,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.55,
    shadowRadius: 20,
    elevation: 14,
    marginTop: 32,
    marginBottom: 12,
  },
  playAgainGrad: {
    borderRadius: 14,
    paddingVertical: 18,
    alignItems: 'center',
    overflow: 'hidden',
    position: 'relative',
  },
  playAgainText: { color: '#000', fontWeight: '900', fontSize: 18, zIndex: 1 },

  homeBtn: {
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#2a2a2a',
    paddingVertical: 16,
    alignItems: 'center',
    overflow: 'hidden',
  },
  homeBtnText: { fontSize: 16, color: '#888' },
});
