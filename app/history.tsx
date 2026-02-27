import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  ImageBackground,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { computePlayerAverages, deleteRound, getRounds } from '../lib/storage';
import { RoundRecord } from '../types';

const GAME_EMOJI: Record<string, string> = {
  taxman: '💰',
  nassau: '🏌️',
  skins: '🎰',
  wolf: '🐺',
  'bingo-bango-bongo': '🎯',
  snake: '🐍',
  scorecard: '📋',
  vegas: '🎰',
  'best-ball': '⚔️',
};

function formatDate(isoString: string): string {
  return new Date(isoString).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function formatAmount(amount: number): string {
  if (amount > 0) return `+$${amount}`;
  if (amount < 0) return `-$${Math.abs(amount)}`;
  return '$0';
}

export default function HistoryScreen() {
  const router = useRouter();
  const [rounds, setRounds] = useState<RoundRecord[]>([]);
  const [loading, setLoading] = useState(true);

  const loadRounds = () => {
    getRounds()
      .then(setRounds)
      .catch(() => setRounds([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadRounds();
  }, []);

  const handleDelete = (id: string) => {
    deleteRound(id)
      .then(() => loadRounds())
      .catch(() => {});
  };

  const averages = computePlayerAverages(rounds);

  return (
    <ImageBackground
      source={require('../assets/bg.png')}
      style={styles.bgFull}
      resizeMode="cover"
    >
      <View style={styles.bgOverlay} />
      <View style={styles.container}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => router.back()} activeOpacity={0.7}>
            <Text style={styles.backBtn}>← History</Text>
          </TouchableOpacity>
        </View>

        <ScrollView
          style={styles.scroll}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {loading ? (
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyText}>Loading...</Text>
            </View>
          ) : rounds.length === 0 ? (
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyText}>
                No rounds yet.{'\n'}Finish a round to see it here.
              </Text>
            </View>
          ) : (
            <>
              {/* Averages Section */}
              {averages.length > 0 && (
                <View style={styles.averagesSection}>
                  <Text style={styles.averagesLabel}>AVERAGES</Text>
                  <ScrollView
                    horizontal
                    showsHorizontalScrollIndicator={false}
                    contentContainerStyle={styles.averagesScroll}
                  >
                    {averages.map((stat) => (
                      <View key={stat.name} style={styles.avgCard}>
                        <Text style={styles.avgName}>{stat.name}</Text>
                        <View style={styles.avgRow}>
                          <Text style={styles.avgLabel}>avg: </Text>
                          <Text style={styles.avgValue}>{stat.avg}</Text>
                        </View>
                        <Text style={styles.avgStrokes}>strokes</Text>
                        <Text style={styles.avgRounds}>({stat.roundsPlayed} rounds)</Text>
                      </View>
                    ))}
                  </ScrollView>
                </View>
              )}

              {/* Rounds List */}
              {rounds.map((round) => {
                const gameEmojis = round.games
                  .map((g) => GAME_EMOJI[g.mode] ?? '')
                  .join(' ');
                const playerNames = round.players.map((p) => p.name).join(', ');
                const combinedNet = round.results?.combinedNet ?? {};

                return (
                  <View key={round.id} style={styles.card}>
                    {/* Date + Games row */}
                    <View style={styles.cardHeader}>
                      <Text style={styles.cardDate}>{formatDate(round.date)}</Text>
                      <Text style={styles.cardEmojis}>{gameEmojis}</Text>
                    </View>

                    {/* Player names */}
                    <Text style={styles.cardPlayers}>{playerNames}</Text>

                    {/* Divider */}
                    <View style={styles.divider} />

                    {/* Net results */}
                    <View style={styles.netRow}>
                      {Object.entries(combinedNet).map(([name, amount]) => {
                        const isPositive = amount > 0;
                        const isNegative = amount < 0;
                        return (
                          <View key={name} style={styles.netItem}>
                            <Text style={styles.netName}>{name}</Text>
                            <Text
                              style={[
                                styles.netAmount,
                                isPositive && styles.netPositive,
                                isNegative && styles.netNegative,
                                !isPositive && !isNegative && styles.netZero,
                              ]}
                            >
                              {formatAmount(amount)}
                            </Text>
                          </View>
                        );
                      })}
                    </View>

                    {/* Delete button */}
                    <TouchableOpacity
                      style={styles.deleteBtn}
                      onPress={() => handleDelete(round.id)}
                      activeOpacity={0.6}
                    >
                      <Text style={styles.deleteBtnText}>🗑</Text>
                    </TouchableOpacity>
                  </View>
                );
              })}
            </>
          )}
        </ScrollView>
      </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  bgFull: { flex: 1, width: '100%' },
  bgOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.65)',
  },
  container: { flex: 1, width: '100%' },
  header: {
    paddingTop: Platform.OS === 'ios' ? 56 : 24,
    paddingHorizontal: 16,
    paddingBottom: 12,
  },
  backBtn: {
    color: '#fff',
    fontSize: 20,
    fontWeight: '700',
  },
  scroll: { flex: 1, width: '100%' },
  scrollContent: {
    padding: 16,
    paddingBottom: 48,
    flexGrow: 1,
    width: '100%',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    color: '#555',
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
  },

  // Averages section
  averagesSection: {
    marginBottom: 24,
  },
  averagesLabel: {
    color: '#666',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 1,
    marginBottom: 8,
  },
  averagesScroll: {
    paddingRight: 16,
  },
  avgCard: {
    backgroundColor: '#161616',
    borderRadius: 12,
    padding: 12,
    marginRight: 8,
    borderWidth: 1,
    borderColor: '#222',
    minWidth: 90,
    alignItems: 'center',
  },
  avgName: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '700',
    marginBottom: 4,
  },
  avgRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
  },
  avgLabel: {
    color: '#888',
    fontSize: 12,
  },
  avgValue: {
    color: '#39FF14',
    fontSize: 20,
    fontWeight: '700',
  },
  avgStrokes: {
    color: '#555',
    fontSize: 11,
    marginTop: 2,
  },
  avgRounds: {
    color: '#444',
    fontSize: 10,
    marginTop: 2,
  },

  // Card styles
  card: {
    backgroundColor: '#161616',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#222',
    marginBottom: 12,
    padding: 16,
    position: 'relative',
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardDate: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  cardEmojis: {
    fontSize: 16,
  },
  cardPlayers: {
    color: '#aaa',
    fontSize: 13,
    marginTop: 4,
  },
  divider: {
    marginTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#2a2a2a',
  },
  netRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: 10,
    gap: 12,
  },
  netItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  netName: {
    color: '#888',
    fontSize: 13,
    fontWeight: '500',
  },
  netAmount: {
    fontSize: 14,
    fontWeight: '700',
  },
  netPositive: {
    color: '#39FF14',
  },
  netNegative: {
    color: '#ff4444',
  },
  netZero: {
    color: '#666',
  },
  deleteBtn: {
    position: 'absolute',
    bottom: 12,
    right: 12,
  },
  deleteBtnText: {
    color: '#444',
    fontSize: 16,
  },
});
