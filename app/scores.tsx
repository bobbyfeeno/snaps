import { useRouter } from 'expo-router';
import { useState } from 'react';
import {
  Modal,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { PlayerResult } from '../types';
import { gameSetup } from './setup';

export let gameResults: PlayerResult[] | null = null;

const NAME_W = 76;
const CELL_W = 36;
const SUM_W = 46;
const ROW_H = 44;

type EditTarget =
  | { kind: 'par'; hole: number }
  | { kind: 'score'; playerId: string; hole: number };

function scoreDotStyle(diff: number): object[] {
  if (diff <= -1) return [styles.dotBase, styles.dotUnder];
  if (diff === 1) return [styles.dotBase, styles.dotBogey];
  if (diff >= 2) return [styles.dotBase, styles.dotDouble];
  return [styles.dotBase, styles.dotPar];
}

export default function ScoresScreen() {
  const router = useRouter();
  const setup = gameSetup;

  const [pars, setPars] = useState<number[]>(Array(18).fill(4));
  const [scores, setScores] = useState<Record<string, (number | null)[]>>(
    () =>
      Object.fromEntries(
        (setup?.players ?? []).map(p => [p.id, Array(18).fill(null)])
      )
  );
  const [target, setTarget] = useState<EditTarget | null>(null);
  const [inputVal, setInputVal] = useState('');

  if (!setup) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>No game setup found.</Text>
        <TouchableOpacity onPress={() => router.replace('/setup')}>
          <Text style={styles.errorLink}>← Back to Setup</Text>
        </TouchableOpacity>
      </View>
    );
  }

  function openEdit(t: EditTarget) {
    if (t.kind === 'par') {
      setInputVal(String(pars[t.hole]));
    } else {
      const v = scores[t.playerId][t.hole];
      setInputVal(v !== null ? String(v) : '');
    }
    setTarget(t);
  }

  function confirmEdit() {
    if (!target) { setTarget(null); return; }
    const n = parseInt(inputVal, 10);
    if (target.kind === 'par') {
      if (!isNaN(n) && n >= 1 && n <= 9) {
        setPars(prev => {
          const next = [...prev];
          next[target.hole] = n;
          return next;
        });
      }
    } else {
      if (!isNaN(n) && n >= 1 && n <= 20) {
        setScores(prev => {
          const arr = [...prev[target.playerId]];
          arr[target.hole] = n;
          return { ...prev, [target.playerId]: arr };
        });
      } else if (inputVal === '') {
        setScores(prev => {
          const arr = [...prev[target.playerId]];
          arr[target.hole] = null;
          return { ...prev, [target.playerId]: arr };
        });
      }
    }
    setTarget(null);
  }

  function sumSlice(arr: (number | null)[], start: number, end: number) {
    return arr.slice(start, end).reduce<number>((a, b) => a + (b ?? 0), 0);
  }
  function allFilled(arr: (number | null)[], start: number, end: number) {
    return arr.slice(start, end).every(v => v !== null);
  }
  function parSum(start: number, end: number) {
    return pars.slice(start, end).reduce((a, b) => a + b, 0);
  }

  function handleCalculate() {
    gameResults = setup!.players.map(player => {
      const s = scores[player.id];
      const total = s.reduce<number>((a, b) => a + (b ?? 0), 0);
      return { player, score: total, beatTaxMan: total > 0 && total < player.taxMan };
    });
    router.push('/results');
  }

  const modalLabel =
    target?.kind === 'par'
      ? `Par · Hole ${target.hole + 1}`
      : target?.kind === 'score'
      ? `${setup.players.find(p => p.id === target.playerId)?.name ?? ''} · Hole ${target.hole + 1}`
      : '';

  return (
    <View style={styles.container}>
      {/* Edit modal */}
      <Modal
        visible={target !== null}
        transparent
        animationType="fade"
        onRequestClose={() => setTarget(null)}
      >
        <TouchableOpacity
          style={styles.modalBg}
          onPress={confirmEdit}
          activeOpacity={1}
        >
          <TouchableOpacity style={styles.modalCard} activeOpacity={1} onPress={() => {}}>
            <Text style={styles.modalTitle}>{modalLabel}</Text>
            <TextInput
              style={styles.modalInput}
              value={inputVal}
              onChangeText={setInputVal}
              keyboardType="number-pad"
              autoFocus
              maxLength={2}
              selectTextOnFocus
              onSubmitEditing={confirmEdit}
            />
            <View style={styles.modalBtns}>
              <TouchableOpacity style={styles.modalCancel} onPress={() => setTarget(null)}>
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.modalConfirm} onPress={confirmEdit}>
                <Text style={styles.modalConfirmText}>Save</Text>
              </TouchableOpacity>
            </View>
          </TouchableOpacity>
        </TouchableOpacity>
      </Modal>

      {/* Scorecard grid */}
      <View style={styles.grid}>
        {/* ── Sticky left column ── */}
        <View style={styles.stickyCol}>
          {/* Header cell */}
          <View style={[styles.cell, styles.hdrCell, { width: NAME_W, height: ROW_H }]}>
            <Text style={styles.hdrText}>NAME</Text>
          </View>
          {/* Par label */}
          <View style={[styles.cell, styles.parLabelCell, { width: NAME_W, height: ROW_H }]}>
            <Text style={styles.parLabelText}>PAR</Text>
          </View>
          {/* Player name cells */}
          {setup.players.map((player, i) => (
            <View
              key={player.id}
              style={[styles.cell, styles.nameCell, { width: NAME_W, height: ROW_H }, i % 2 === 1 && styles.rowAlt]}
            >
              <Text style={styles.nameText} numberOfLines={1}>{player.name}</Text>
              <Text style={styles.tmText}>TM {player.taxMan}</Text>
            </View>
          ))}
        </View>

        {/* ── Horizontally scrollable columns ── */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} bounces={false}>
          <View>
            {/* Header row */}
            <View style={{ flexDirection: 'row', height: ROW_H }}>
              {[0,1,2,3,4,5,6,7,8].map(i => (
                <View key={i} style={[styles.cell, styles.hdrCell, { width: CELL_W }]}>
                  <Text style={styles.hdrText}>{i + 1}</Text>
                </View>
              ))}
              <View style={[styles.cell, styles.sumHdrCell, { width: SUM_W }]}>
                <Text style={styles.sumHdrText}>OUT</Text>
              </View>
              {[9,10,11,12,13,14,15,16,17].map(i => (
                <View key={i} style={[styles.cell, styles.hdrCell, { width: CELL_W }]}>
                  <Text style={styles.hdrText}>{i + 1}</Text>
                </View>
              ))}
              <View style={[styles.cell, styles.sumHdrCell, { width: SUM_W }]}>
                <Text style={styles.sumHdrText}>IN</Text>
              </View>
              <View style={[styles.cell, styles.sumHdrCell, { width: SUM_W }]}>
                <Text style={styles.sumHdrText}>TOT</Text>
              </View>
            </View>

            {/* Par row */}
            <View style={{ flexDirection: 'row', height: ROW_H }}>
              {[0,1,2,3,4,5,6,7,8].map(i => (
                <TouchableOpacity
                  key={i}
                  onPress={() => openEdit({ kind: 'par', hole: i })}
                  style={[styles.cell, styles.parCell, { width: CELL_W }]}
                >
                  <Text style={styles.parText}>{pars[i]}</Text>
                </TouchableOpacity>
              ))}
              <View style={[styles.cell, styles.sumCell, { width: SUM_W }]}>
                <Text style={styles.sumText}>{parSum(0, 9)}</Text>
              </View>
              {[9,10,11,12,13,14,15,16,17].map(i => (
                <TouchableOpacity
                  key={i}
                  onPress={() => openEdit({ kind: 'par', hole: i })}
                  style={[styles.cell, styles.parCell, { width: CELL_W }]}
                >
                  <Text style={styles.parText}>{pars[i]}</Text>
                </TouchableOpacity>
              ))}
              <View style={[styles.cell, styles.sumCell, { width: SUM_W }]}>
                <Text style={styles.sumText}>{parSum(9, 18)}</Text>
              </View>
              <View style={[styles.cell, styles.sumCell, { width: SUM_W }]}>
                <Text style={styles.sumText}>{parSum(0, 18)}</Text>
              </View>
            </View>

            {/* Player rows */}
            {setup.players.map((player, pi) => {
              const s = scores[player.id];
              const outVal = sumSlice(s, 0, 9);
              const outDone = allFilled(s, 0, 9);
              const inVal = sumSlice(s, 9, 18);
              const inDone = allFilled(s, 9, 18);
              const totVal = outVal + inVal;
              const totDone = outDone && inDone;
              const isWin = totDone && totVal > 0 && totVal < player.taxMan;
              const isLose = totDone && totVal >= player.taxMan;

              return (
                <View
                  key={player.id}
                  style={[{ flexDirection: 'row', height: ROW_H }, pi % 2 === 1 && styles.rowAlt]}
                >
                  {[0,1,2,3,4,5,6,7,8].map(i => {
                    const v = s[i];
                    const diff = v !== null ? v - pars[i] : 0;
                    return (
                      <TouchableOpacity
                        key={i}
                        onPress={() => openEdit({ kind: 'score', playerId: player.id, hole: i })}
                        style={[styles.cell, styles.scoreCell, { width: CELL_W }]}
                      >
                        {v !== null ? (
                          <View style={scoreDotStyle(diff) as any}>
                            <Text style={[styles.scoreText, diff < 0 && styles.stUnder, diff > 0 && styles.stOver]}>
                              {v}
                            </Text>
                          </View>
                        ) : (
                          <Text style={styles.emptyDot}>·</Text>
                        )}
                      </TouchableOpacity>
                    );
                  })}
                  <View style={[styles.cell, styles.sumCell, { width: SUM_W }]}>
                    <Text style={styles.sumText}>{outDone ? outVal : '—'}</Text>
                  </View>
                  {[9,10,11,12,13,14,15,16,17].map(i => {
                    const v = s[i];
                    const diff = v !== null ? v - pars[i] : 0;
                    return (
                      <TouchableOpacity
                        key={i}
                        onPress={() => openEdit({ kind: 'score', playerId: player.id, hole: i })}
                        style={[styles.cell, styles.scoreCell, { width: CELL_W }]}
                      >
                        {v !== null ? (
                          <View style={scoreDotStyle(diff) as any}>
                            <Text style={[styles.scoreText, diff < 0 && styles.stUnder, diff > 0 && styles.stOver]}>
                              {v}
                            </Text>
                          </View>
                        ) : (
                          <Text style={styles.emptyDot}>·</Text>
                        )}
                      </TouchableOpacity>
                    );
                  })}
                  <View style={[styles.cell, styles.sumCell, { width: SUM_W }]}>
                    <Text style={styles.sumText}>{inDone ? inVal : '—'}</Text>
                  </View>
                  <View style={[styles.cell, styles.sumCell, { width: SUM_W }]}>
                    <Text style={[
                      styles.sumText,
                      styles.totText,
                      isWin && styles.totWin,
                      isLose && styles.totLose,
                    ]}>
                      {totDone ? totVal : '—'}
                    </Text>
                  </View>
                </View>
              );
            })}
          </View>
        </ScrollView>
      </View>

      {/* Footer */}
      <View style={styles.footer}>
        <TouchableOpacity style={styles.calcBtn} onPress={handleCalculate} activeOpacity={0.8}>
          <Text style={styles.calcBtnText}>Calculate Payout →</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },

  errorContainer: { flex: 1, backgroundColor: '#000', alignItems: 'center', justifyContent: 'center' },
  errorText: { color: '#ff5555', fontSize: 18, marginBottom: 16 },
  errorLink: { color: '#39FF14', fontSize: 16 },

  grid: { flex: 1, flexDirection: 'row' },

  stickyCol: { zIndex: 10 },

  rowAlt: { backgroundColor: '#0c0c0c' },

  cell: {
    justifyContent: 'center',
    alignItems: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderRightWidth: StyleSheet.hairlineWidth,
    borderColor: '#2a2a2a',
  },

  // Header (hole numbers)
  hdrCell: { backgroundColor: '#39FF14' },
  hdrText: { color: '#000', fontWeight: '800', fontSize: 12 },

  // OUT / IN / TOT headers
  sumHdrCell: { backgroundColor: '#1fcb04' },
  sumHdrText: { color: '#000', fontWeight: '900', fontSize: 11, letterSpacing: 0.3 },

  // Par label on sticky col
  parLabelCell: { backgroundColor: '#141414' },
  parLabelText: { color: '#666', fontWeight: '700', fontSize: 12, letterSpacing: 1 },

  // Player name cells (sticky)
  nameCell: { backgroundColor: '#0d0d0d', paddingHorizontal: 6, alignItems: 'flex-start' },
  nameText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  tmText: { color: '#39FF14', fontSize: 9, fontWeight: '700', marginTop: 1 },

  // Par cells
  parCell: { backgroundColor: '#141414' },
  parText: { color: '#999', fontSize: 13, fontWeight: '500' },

  // OUT/IN/TOT value cells
  sumCell: { backgroundColor: '#111' },
  sumText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  totText: { fontWeight: '800' },
  totWin: { color: '#39FF14' },
  totLose: { color: '#ff5555' },

  // Score cells
  scoreCell: { backgroundColor: 'transparent' },

  dotBase: {
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  dotPar: { backgroundColor: '#1a1a1a' },
  dotUnder: { backgroundColor: '#002200', borderWidth: 1.5, borderColor: '#39FF14' },
  dotBogey: { backgroundColor: '#2a0808', borderWidth: 1, borderColor: '#883333' },
  dotDouble: { backgroundColor: '#1f0000', borderWidth: 2, borderColor: '#cc2222' },

  scoreText: { fontSize: 12, fontWeight: '700', color: '#ccc' },
  stUnder: { color: '#39FF14' },
  stOver: { color: '#ff6666' },
  emptyDot: { color: '#2a2a2a', fontSize: 18 },

  // Modal
  modalBg: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.75)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalCard: {
    backgroundColor: '#141414',
    borderRadius: 20,
    padding: 24,
    width: 240,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#2a2a2a',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.6,
    shadowRadius: 20,
    elevation: 20,
  },
  modalTitle: { color: '#39FF14', fontWeight: '700', fontSize: 15, marginBottom: 16, letterSpacing: 0.3 },
  modalInput: {
    backgroundColor: '#000',
    borderWidth: 2,
    borderColor: '#39FF14',
    borderRadius: 14,
    fontSize: 44,
    fontWeight: '800',
    color: '#fff',
    width: 130,
    textAlign: 'center',
    paddingVertical: 10,
    marginBottom: 20,
  },
  modalBtns: { flexDirection: 'row', gap: 10, width: '100%' },
  modalCancel: {
    flex: 1,
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#333',
  },
  modalCancelText: { color: '#666', fontWeight: '600', fontSize: 15 },
  modalConfirm: {
    flex: 1,
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: 10,
    backgroundColor: '#39FF14',
  },
  modalConfirmText: { color: '#000', fontWeight: '800', fontSize: 15 },

  // Footer
  footer: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: Platform.OS === 'ios' ? 32 : 16,
    backgroundColor: '#000',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#2a2a2a',
  },
  calcBtn: {
    backgroundColor: '#39FF14',
    borderRadius: 14,
    paddingVertical: 18,
    alignItems: 'center',
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  calcBtnText: { fontSize: 18, fontWeight: '800', color: '#000' },
});
