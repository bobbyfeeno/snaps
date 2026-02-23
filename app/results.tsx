import { useRouter } from 'expo-router';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { Payout, PlayerResult } from '../types';
import { gameResults, resetGameResults } from './scores';
import { gameSetup, resetGameSetup } from './setup';

function buildPayouts(results: PlayerResult[], taxAmount: number): Payout[] {
  const winners = results.filter(r => r.beatTaxMan);
  const losers = results.filter(r => !r.beatTaxMan);
  const payouts: Payout[] = [];

  for (const loser of losers) {
    for (const winner of winners) {
      payouts.push({
        from: loser.player.name,
        to: winner.player.name,
        amount: taxAmount,
      });
    }
  }
  return payouts;
}

function formatMoney(n: number) {
  return n % 1 === 0 ? `$${n}` : `$${n.toFixed(2)}`;
}

export default function ResultsScreen() {
  const router = useRouter();
  const results = gameResults;
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

  const winners = results.filter(r => r.beatTaxMan);
  const losers = results.filter(r => !r.beatTaxMan);
  const payouts = buildPayouts(results, setup.taxAmount);

  // Net per player
  const net: Record<string, number> = {};
  for (const r of results) {
    net[r.player.name] = 0;
  }
  for (const p of payouts) {
    net[p.from] -= p.amount;
    net[p.to] += p.amount;
  }

  const sortedResults = [...results].sort((a, b) => a.score - b.score);

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
          <Text style={styles.summaryNum}>{formatMoney(setup.taxAmount)}</Text>
          <Text style={styles.summaryLabel}>Per Win</Text>
        </View>
      </View>

      {/* Scoreboard */}
      <Text style={styles.sectionLabel}>Scoreboard</Text>
      {sortedResults.map(r => (
        <View
          key={r.player.id}
          style={[styles.scoreRow, r.beatTaxMan ? styles.scoreRowWin : styles.scoreRowLose]}
        >
          <View style={styles.scoreLeft}>
            <Text style={[styles.scoreIcon]}>{r.beatTaxMan ? '✓' : '✗'}</Text>
            <View>
              <Text style={styles.scoreName}>{r.player.name}</Text>
              <Text style={styles.scoreDetail}>
                Tax Man {r.player.taxMan} · Shot {r.score}
                {' · '}
                {r.beatTaxMan
                  ? `${r.player.taxMan - r.score} under`
                  : `${r.score - r.player.taxMan} over`}
              </Text>
            </View>
          </View>
          <View style={[styles.netBadge, net[r.player.name] >= 0 ? styles.netBadgePos : styles.netBadgeNeg]}>
            <Text style={styles.netText}>
              {net[r.player.name] >= 0 ? '+' : ''}{formatMoney(net[r.player.name])}
            </Text>
          </View>
        </View>
      ))}

      {/* Payouts */}
      {payouts.length > 0 ? (
        <>
          <Text style={[styles.sectionLabel, { marginTop: 28 }]}>Payouts</Text>
          {payouts.map((p, i) => (
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
        </>
      ) : (
        <View style={styles.noPayoutsCard}>
          <Text style={styles.noPayoutsText}>
            {winners.length === 0
              ? 'Nobody beat their Tax Man — no payouts.'
              : 'Everyone beat their Tax Man — no payouts!'}
          </Text>
        </View>
      )}

      {/* Totals */}
      {payouts.length > 0 && (
        <>
          <Text style={[styles.sectionLabel, { marginTop: 28 }]}>Net Totals</Text>
          {Object.entries(net)
            .sort((a, b) => b[1] - a[1])
            .map(([name, amount]) => (
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
    marginBottom: 24,
  },
  summaryItem: { flex: 1, alignItems: 'center' },
  summaryNum: { fontSize: 28, fontWeight: '800', color: '#39FF14' },
  summaryLabel: { fontSize: 12, color: '#5a8a5a', marginTop: 2, textTransform: 'uppercase', letterSpacing: 0.5 },
  summaryDivider: { width: 1, backgroundColor: '#2a4a2a', marginVertical: 8 },

  sectionLabel: { fontSize: 18, fontWeight: '700', color: '#39FF14', marginBottom: 10 },

  scoreRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderRadius: 12,
    borderWidth: 1,
    padding: 14,
    marginBottom: 10,
  },
  scoreRowWin: { backgroundColor: '#0f2a0f', borderColor: '#39FF14' },
  scoreRowLose: { backgroundColor: '#2a0f0f', borderColor: '#cc3333' },
  scoreLeft: { flexDirection: 'row', alignItems: 'center', flex: 1 },
  scoreIcon: { fontSize: 22, marginRight: 12, color: '#fff' },
  scoreName: { fontSize: 18, fontWeight: '700', color: '#fff' },
  scoreDetail: { fontSize: 12, color: '#88bb88', marginTop: 2 },

  netBadge: { borderRadius: 8, paddingHorizontal: 12, paddingVertical: 6, minWidth: 70, alignItems: 'center' },
  netBadgePos: { backgroundColor: '#1a3d1a' },
  netBadgeNeg: { backgroundColor: '#3d1a1a' },
  netText: { fontSize: 17, fontWeight: '800', color: '#fff' },

  payoutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#162416',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    padding: 14,
    marginBottom: 8,
  },
  payoutFrom: { fontSize: 15, fontWeight: '700', color: '#ff6666', flex: 1 },
  payoutArrowContainer: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8, flex: 1.4, justifyContent: 'center' },
  payoutLine: { height: 1, flex: 1, backgroundColor: '#2a4a2a' },
  payoutAmount: { fontSize: 15, fontWeight: '800', color: '#fff', marginHorizontal: 6 },
  payoutArrow: { fontSize: 16, color: '#39FF14', marginLeft: 2 },
  payoutTo: { fontSize: 15, fontWeight: '700', color: '#39FF14', flex: 1, textAlign: 'right' },

  noPayoutsCard: {
    backgroundColor: '#162416',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    padding: 20,
    marginTop: 8,
    alignItems: 'center',
  },
  noPayoutsText: { fontSize: 15, color: '#88bb88', textAlign: 'center' },

  totalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 4,
    borderBottomWidth: 1,
    borderBottomColor: '#1e3a1e',
  },
  totalName: { fontSize: 17, color: '#fff', fontWeight: '600' },
  totalAmount: { fontSize: 20, fontWeight: '800' },
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
