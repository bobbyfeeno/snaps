import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ImageBackground,
  Modal,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { BevelCard } from '../components/BevelCard';
import { calcAllGames, calcLiveStatus, GameExtras, LiveStatus, LiveStatusLine } from '../lib/gameEngines';
import { BBBHoleState, GameMode, GameSetup, MultiGameResults, NassauConfig, PressMatch, SnakeHoleState, VegasConfig, WolfHoleState } from '../types';
import { gameSetup } from './setup';

// Export multiGameResults for results screen
export let multiGameResults: MultiGameResults | null = null;

export function resetGameResults() {
  multiGameResults = null;
}

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

const DEMO_SETUP: GameSetup = {
  players: [
    { id: 'p1', name: 'Bobby', taxMan: 85 },
    { id: 'p2', name: 'Mike', taxMan: 90 },
    { id: 'p3', name: 'Dave', taxMan: 95 },
    { id: 'p4', name: 'Chris', taxMan: 92 },
  ],
  games: [{ mode: 'taxman', config: { taxAmount: 10 } }],
};

const DEMO_SCORES: Record<string, (number | null)[]> = {
  p1: [4,3,5,4,4,3,4,5,4, 4,4,3,5,4,4,3,4,5],
  p2: [5,4,5,4,4,4,4,5,4, 5,4,4,5,4,4,4,4,5],
  p3: [4,4,4,4,5,3,4,5,4, 4,5,3,4,4,5,3,4,5],
  p4: [4,3,4,5,4,3,5,4,4, 4,3,4,5,4,3,5,4,4],
};

// Helper to check if a game mode is active
function hasGame(modes: GameMode[], mode: GameMode): boolean {
  return modes.includes(mode);
}

export default function ScoresScreen() {
  const router = useRouter();
  const { preview } = useLocalSearchParams<{ preview?: string }>();
  // Explicitly convert to boolean to avoid New Architecture type coercion issues
  const isPreview = Boolean(preview === 'true' || !gameSetup);
  const setup = isPreview ? DEMO_SETUP : gameSetup!;
  const activeGameModes = setup.games.map(g => g.mode);

  const [pars, setPars] = useState<number[]>([4,3,5,4,4,3,4,5,4, 4,4,3,5,4,4,3,4,5]);
  const [scores, setScores] = useState<Record<string, (number | null)[]>>(
    () => isPreview
      ? DEMO_SCORES
      : Object.fromEntries(
          setup.players.map(p => [p.id, Array(18).fill(null)])
        )
  );
  const [target, setTarget] = useState<EditTarget | null>(null);
  const [inputVal, setInputVal] = useState('');

  // ─── Game extras state ────────────────────────────────────────────────────
  const [wolfHoles, setWolfHoles] = useState<(WolfHoleState | null)[]>(() => 
    Array(18).fill(null).map((_, i) => ({
      wolfPlayerId: setup.players[i % setup.players.length].id,
      partnerId: null,
    }))
  );
  
  const [bbbHoles, setBbbHoles] = useState<(BBBHoleState | null)[]>(() =>
    Array(18).fill(null).map(() => ({
      bingoPlayerId: null,
      bangoPlayerId: null,
      bongoPlayerId: null,
    }))
  );
  
  const [snakeHoles, setSnakeHoles] = useState<(SnakeHoleState | null)[]>(() =>
    Array(18).fill(null).map(() => ({
      holderPlayerId: null,
      threeputters: [],
    }))
  );

  // ─── Hammer multipliers (per-hole, for Vegas/Nassau with Hammer enabled) ────
  const [hammerMultipliers, setHammerMultipliers] = useState<number[]>(() => Array(18).fill(1));

  function cycleHammer(hole: number) {
    setHammerMultipliers(prev => {
      const next = [...prev];
      const cur = next[hole];
      next[hole] = cur >= 8 ? 1 : cur * 2;
      return next;
    });
  }

  // ─── Press state (Nassau match play auto-press) ───────────────────────────
  const [pressMatches, setPressMatches] = useState<PressMatch[]>([]);

  // Check if Nassau auto-press is active
  const nassauGame = setup.games.find(g => g.mode === 'nassau');
  const nassauConfig = nassauGame?.config as NassauConfig | undefined;
  const hasNassauAutoPress = !!nassauGame && nassauConfig?.mode === 'match' && nassauConfig?.press === 'auto';
  const useHandicaps = !!nassauGame && !!nassauConfig?.useHandicaps;

  // Collapsible panel states
  const [wolfExpanded, setWolfExpanded] = useState(false);
  const [bbbExpanded, setBbbExpanded] = useState(false);
  const [snakeExpanded, setSnakeExpanded] = useState(false);

  // ─── Live Status ──────────────────────────────────────────────────────────
  const liveStatus = useMemo(() => 
    calcLiveStatus(setup, scores, pars, wolfHoles, bbbHoles, snakeHoles, pressMatches),
    [setup, scores, pars, wolfHoles, bbbHoles, snakeHoles, pressMatches]
  );

  function openEdit(t: EditTarget) {
    if (isPreview) return;
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
        // Check for auto-press after score entry
        setTimeout(() => checkAutoPress(), 0);
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

  // ─── Wolf helpers ─────────────────────────────────────────────────────────
  function setWolfPartner(hole: number, partnerId: string | null) {
    setWolfHoles(prev => {
      const next = [...prev];
      const current = next[hole];
      if (current) {
        next[hole] = { ...current, partnerId };
      }
      return next;
    });
  }

  // ─── BBB helpers ──────────────────────────────────────────────────────────
  function cyclePlayer(hole: number, field: 'bingoPlayerId' | 'bangoPlayerId' | 'bongoPlayerId') {
    setBbbHoles(prev => {
      const next = [...prev];
      const current = next[hole];
      if (!current) return prev;
      
      const currentId = current[field];
      const playerIds = setup.players.map(p => p.id);
      const currentIndex = currentId ? playerIds.indexOf(currentId) : -1;
      const nextIndex = (currentIndex + 1) % (playerIds.length + 1);
      const nextId = nextIndex < playerIds.length ? playerIds[nextIndex] : null;
      
      next[hole] = { ...current, [field]: nextId };
      return next;
    });
  }

  // ─── Snake helpers ────────────────────────────────────────────────────────
  function toggleThreePutt(hole: number, playerId: string) {
    setSnakeHoles(prev => {
      const next = [...prev];
      const current = next[hole];
      if (!current) return prev;
      
      const threeputters = current.threeputters.includes(playerId)
        ? current.threeputters.filter(id => id !== playerId)
        : [...current.threeputters, playerId];
      
      next[hole] = { ...current, threeputters };
      return next;
    });
  }

  function getSnakeHolder(): string | null {
    let holder: string | null = null;
    for (const state of snakeHoles) {
      if (state && state.threeputters.length > 0) {
        holder = state.threeputters[state.threeputters.length - 1];
      }
    }
    return holder;
  }

  // ─── Auto-press check ─────────────────────────────────────────────────────
  function checkAutoPress() {
    if (!hasNassauAutoPress) return;

    const legs: { name: 'front' | 'back' | 'full'; start: number; end: number }[] = [
      { name: 'front', start: 0, end: 9 },
      { name: 'back', start: 9, end: 18 },
    ];

    const newPresses: PressMatch[] = [];

    for (const leg of legs) {
      // Find current hole being played in this leg
      let currentHole = -1;
      for (let h = leg.start; h < leg.end; h++) {
        const allHaveScore = setup.players.every(p => scores[p.id][h] !== null);
        if (allHaveScore) {
          currentHole = h;
        }
      }

      if (currentHole < leg.start) continue; // No completed holes in this leg yet

      // Calculate holes won per player up to and including currentHole
      const holesWon: Record<string, number> = {};
      for (const p of setup.players) holesWon[p.id] = 0;

      for (let h = leg.start; h <= currentHole; h++) {
        const holeScores = setup.players
          .map(p => ({ id: p.id, score: scores[p.id][h] }))
          .filter(x => x.score !== null) as { id: string; score: number }[];
        
        if (holeScores.length < 2) continue;

        const minScore = Math.min(...holeScores.map(x => x.score));
        const winners = holeScores.filter(x => x.score === minScore);
        if (winners.length === 1) {
          holesWon[winners[0].id]++;
        }
      }

      // Find leader and check if anyone is 2+ down
      const maxWon = Math.max(...Object.values(holesWon));
      
      for (const p of setup.players) {
        const deficit = maxWon - holesWon[p.id];
        if (deficit >= 2 && currentHole < leg.end - 1) {
          // Player is 2+ down and there are holes remaining
          const nextHole = currentHole + 1;
          
          // Check if a press already covers this situation
          const alreadyPressed = pressMatches.some(pm =>
            pm.leg === leg.name && pm.startHole <= nextHole && pm.endHole >= nextHole
          ) || newPresses.some(pm =>
            pm.leg === leg.name && pm.startHole <= nextHole && pm.endHole >= nextHole
          );

          if (!alreadyPressed) {
            newPresses.push({
              id: `${leg.name}-${nextHole}-${Date.now()}`,
              leg: leg.name,
              startHole: nextHole,
              endHole: leg.end - 1,
            });
          }
        }
      }
    }

    if (newPresses.length > 0) {
      setPressMatches(prev => [...prev, ...newPresses]);
    }
  }

  function handleCalculate() {
    const extras: GameExtras = {
      wolf: wolfHoles,
      bbb: bbbHoles,
      snake: snakeHoles,
      pressMatches: pressMatches,
      hammerMultipliers: hammerMultipliers,
      pars: pars,
    };
    
    multiGameResults = calcAllGames(setup, scores, extras);
    router.push('/results');
  }

  const modalLabel =
    target?.kind === 'par'
      ? `Par · Hole ${target.hole + 1}`
      : target?.kind === 'score'
      ? `${setup.players.find(p => p.id === target.playerId)?.name ?? ''} · Hole ${target.hole + 1}`
      : '';

  const hasWolf = hasGame(activeGameModes, 'wolf');
  const hasBBB = hasGame(activeGameModes, 'bingo-bango-bongo');
  const hasHammer = setup.games.some(g =>
    (g.mode === 'vegas' && (g.config as VegasConfig).useHammer) ||
    (g.mode === 'nassau' && (g.config as NassauConfig).useHammer)
  );
  const hasSnake = hasGame(activeGameModes, 'snake');
  const hasExtras = hasWolf || hasBBB || hasSnake;

  return (
    <ImageBackground source={require('../assets/bg.png')} style={styles.bgFull} resizeMode="cover">
      <View style={styles.bgOverlay} />
      <View style={styles.container}>
      {/* Radial center glow */}
      <View style={styles.centerGlow} pointerEvents="none" />

      {/* Preview mode banner */}
      {isPreview && (
        <LinearGradient
          colors={['#1e1e1e', '#141414']}
          style={styles.previewBanner}
        >
          <View style={styles.cardHighlight} />
          <Text style={styles.previewIcon}>👀</Text>
          <View style={styles.previewTextContainer}>
            <Text style={styles.previewTitle}>Preview Mode</Text>
            <Text style={styles.previewSubtitle}>Sample data — scores are locked</Text>
          </View>
          <TouchableOpacity
            style={styles.previewCTAOuter}
            onPress={() => router.replace('/setup')}
            activeOpacity={0.8}
          >
            <LinearGradient
              colors={['#44ff18', '#28cc08']}
              style={styles.previewCTAInner}
            >
              <View
                style={[StyleSheet.absoluteFill, { borderRadius: 8, overflow: 'hidden' }]}
              />
              <Text style={styles.previewCTAText}>Start Game</Text>
            </LinearGradient>
          </TouchableOpacity>
        </LinearGradient>
      )}

      {/* Edit modal */}
      <Modal
        visible={Boolean(target !== null)}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setTarget(null)}
      >
        <TouchableOpacity
          style={styles.modalBg}
          onPress={confirmEdit}
          activeOpacity={1}
        >
          <TouchableOpacity activeOpacity={1} onPress={() => {}}>
            <BevelCard style={styles.modalCard}>
              <View style={styles.modalCardInner}>
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
                  <TouchableOpacity style={styles.modalCancelOuter} onPress={() => setTarget(null)}>
                    <LinearGradient
                      colors={['#1e1e1e', '#141414']}
                      style={styles.modalCancelInner}
                    >
                      <View
                        style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
                      />
                      <Text style={styles.modalCancelText}>Cancel</Text>
                    </LinearGradient>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.modalConfirmOuter} onPress={confirmEdit}>
                    <LinearGradient
                      colors={['#52ff20', '#2dcc08', '#1fa005']}
                      locations={[0, 0.6, 1]}
                      style={styles.modalConfirmInner}
                    >
                      <View style={styles.btnSpecular} />
                      <View style={styles.btnEdgeTop} />
                      <View style={styles.btnEdgeBottom} />
                      <View
                        style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
                      />
                      <Text style={styles.modalConfirmText}>Save</Text>
                    </LinearGradient>
                  </TouchableOpacity>
                </View>
              </View>
            </BevelCard>
          </TouchableOpacity>
        </TouchableOpacity>
      </Modal>

      <ScrollView style={styles.mainScroll} bounces={false}>
        {/* Scorecard grid */}
        <View style={styles.grid}>
          {/* ── Sticky left column ── */}
          <View style={styles.stickyCol}>
            {/* Header cell */}
            <LinearGradient
              colors={['#1e1e1e', '#141414']}
              style={[styles.cell, styles.hdrCell, { width: NAME_W, height: ROW_H }]}
            >
              <Text style={styles.hdrText}>NAME</Text>
            </LinearGradient>
            {/* Par label */}
            <View style={[styles.cell, styles.parLabelCell, { width: NAME_W, height: ROW_H }]}>
              <Text style={styles.parLabelText}>PAR</Text>
            </View>
            {/* Player name cells */}
            {setup.players.map((player, i) => (
              <LinearGradient
                key={player.id}
                colors={['#141414', '#0d0d0d']}
                style={[styles.cell, styles.nameCell, { width: NAME_W, height: ROW_H }, i % 2 === 1 && styles.rowAlt]}
              >
                <Text style={styles.nameText} numberOfLines={1}>
                  {hasSnake && getSnakeHolder() === player.id ? '🐍 ' : ''}{player.name}
                </Text>
                <Text style={styles.tmText}>TM {player.taxMan}</Text>
                {useHandicaps && player.handicap !== undefined && (
                  <Text style={styles.hcpText}>HCP {player.handicap}</Text>
                )}
              </LinearGradient>
            ))}
          </View>

          {/* ── Horizontally scrollable columns ── */}
          <ScrollView horizontal showsHorizontalScrollIndicator={false} bounces={false} style={{ flex: 1 }}>
            <View>
              {/* Header row */}
              <View style={{ flexDirection: 'row', height: ROW_H }}>
                {[0,1,2,3,4,5,6,7,8].map(i => (
                  <LinearGradient
                    key={i}
                    colors={['#1e1e1e', '#141414']}
                    style={[styles.cell, styles.hdrCell, { width: CELL_W }]}
                  >
                    <Text style={styles.hdrText}>{i + 1}</Text>
                  </LinearGradient>
                ))}
                <LinearGradient
                  colors={['#1e1e1e', '#141414']}
                  style={[styles.cell, styles.sumHdrCell, { width: SUM_W }]}
                >
                  <Text style={styles.sumHdrText}>OUT</Text>
                </LinearGradient>
                {[9,10,11,12,13,14,15,16,17].map(i => (
                  <LinearGradient
                    key={i}
                    colors={['#1e1e1e', '#141414']}
                    style={[styles.cell, styles.hdrCell, { width: CELL_W }]}
                  >
                    <Text style={styles.hdrText}>{i + 1}</Text>
                  </LinearGradient>
                ))}
                <LinearGradient
                  colors={['#1e1e1e', '#141414']}
                  style={[styles.cell, styles.sumHdrCell, { width: SUM_W }]}
                >
                  <Text style={styles.sumHdrText}>IN</Text>
                </LinearGradient>
                <LinearGradient
                  colors={['#1e1e1e', '#141414']}
                  style={[styles.cell, styles.sumHdrCell, { width: SUM_W }]}
                >
                  <Text style={styles.sumHdrText}>TOT</Text>
                </LinearGradient>
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

              {/* Hammer row (shown when any active game has Hammer enabled) */}
              {hasHammer && (
                <View style={{ flexDirection: 'row', height: ROW_H, backgroundColor: '#0a0a0a' }}>
                  {[0,1,2,3,4,5,6,7,8].map(i => (
                    <TouchableOpacity
                      key={i}
                      onPress={() => cycleHammer(i)}
                      style={[styles.cell, styles.hammerCell, { width: CELL_W }]}
                    >
                      <Text style={[styles.hammerText, hammerMultipliers[i] > 1 && styles.hammerTextActive]}>
                        ×{hammerMultipliers[i]}
                      </Text>
                    </TouchableOpacity>
                  ))}
                  <View style={[styles.cell, styles.hammerCell, { width: SUM_W }]} />
                  {[9,10,11,12,13,14,15,16,17].map(i => (
                    <TouchableOpacity
                      key={i}
                      onPress={() => cycleHammer(i)}
                      style={[styles.cell, styles.hammerCell, { width: CELL_W }]}
                    >
                      <Text style={[styles.hammerText, hammerMultipliers[i] > 1 && styles.hammerTextActive]}>
                        ×{hammerMultipliers[i]}
                      </Text>
                    </TouchableOpacity>
                  ))}
                  <View style={[styles.cell, styles.hammerCell, { width: SUM_W }]} />
                  <View style={[styles.cell, styles.hammerCell, { width: SUM_W }]} />
                </View>
              )}

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
                          style={[styles.cell, styles.scoreCell, { width: CELL_W, backgroundColor: i % 2 === 0 ? '#0a0a0a' : '#0c0c0c' }]}
                        >
                          <View
                            style={StyleSheet.absoluteFill}
                          />
                          {v !== null ? (
                            <View style={scoreDotStyle(diff) as object}>
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
                          style={[styles.cell, styles.scoreCell, { width: CELL_W, backgroundColor: i % 2 === 0 ? '#0a0a0a' : '#0c0c0c' }]}
                        >
                          <View
                            style={StyleSheet.absoluteFill}
                          />
                          {v !== null ? (
                            <View style={scoreDotStyle(diff) as object}>
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

        {/* ─── Game Extras Panels ─────────────────────────────────────────────── */}
        {hasExtras && !isPreview && (
          <View style={styles.extrasContainer}>
            {/* Wolf Panel */}
            {hasWolf && setup.players.length < 3 && (
              <View style={styles.wolfWarning}>
                <Text style={styles.wolfWarningText}>⚠️ Wolf requires 3+ players</Text>
              </View>
            )}
            {hasWolf && setup.players.length >= 3 && (
              <LinearGradient
                colors={['#212121', '#141414']}
                style={styles.extrasPanel}
              >
                <View style={styles.cardHighlight} />
                <TouchableOpacity 
                  style={styles.extrasPanelHeader}
                  onPress={() => setWolfExpanded(!wolfExpanded)}
                  activeOpacity={0.7}
                >
                  <Text style={styles.extrasPanelTitle}>🐺 Wolf</Text>
                  <Text style={styles.extrasPanelToggle}>{wolfExpanded ? '▾' : '▸'}</Text>
                </TouchableOpacity>
                
                {wolfExpanded && (
                  <ScrollView style={styles.extrasPanelContent} nestedScrollEnabled>
                    {Array(18).fill(null).map((_, hole) => {
                      const wolfState = wolfHoles[hole];
                      const wolfPlayer = setup.players.find(p => p.id === wolfState?.wolfPlayerId);
                      const partnerPlayer = wolfState?.partnerId 
                        ? setup.players.find(p => p.id === wolfState.partnerId)
                        : null;
                      const isLoneWolf = wolfState?.partnerId === null;
                      
                      return (
                        <View key={hole} style={styles.wolfRow}>
                          <Text style={styles.wolfHoleNum}>H{hole + 1}</Text>
                          <Text style={styles.wolfLabel}>Wolf:</Text>
                          <Text style={styles.wolfName}>{wolfPlayer?.name ?? '?'}</Text>
                          <Text style={styles.wolfLabel}>Partner:</Text>
                          <View style={styles.wolfPartnerPicker}>
                            <TouchableOpacity
                              style={[styles.wolfPartnerBtn, isLoneWolf && styles.wolfPartnerBtnActive]}
                              onPress={() => setWolfPartner(hole, null)}
                            >
                              <Text style={[styles.wolfPartnerBtnText, isLoneWolf && styles.wolfPartnerBtnTextActive]}>
                                Lone
                              </Text>
                            </TouchableOpacity>
                            {setup.players
                              .filter(p => p.id !== wolfState?.wolfPlayerId)
                              .map(p => (
                                <TouchableOpacity
                                  key={p.id}
                                  style={[
                                    styles.wolfPartnerBtn,
                                    wolfState?.partnerId === p.id && styles.wolfPartnerBtnActive
                                  ]}
                                  onPress={() => setWolfPartner(hole, p.id)}
                                >
                                  <Text style={[
                                    styles.wolfPartnerBtnText,
                                    wolfState?.partnerId === p.id && styles.wolfPartnerBtnTextActive
                                  ]}>
                                    {p.name.slice(0, 4)}
                                  </Text>
                                </TouchableOpacity>
                              ))}
                          </View>
                        </View>
                      );
                    })}
                  </ScrollView>
                )}
              </LinearGradient>
            )}

            {/* BBB Panel */}
            {hasBBB && (
              <LinearGradient
                colors={['#212121', '#141414']}
                style={styles.extrasPanel}
              >
                <View style={styles.cardHighlight} />
                <TouchableOpacity 
                  style={styles.extrasPanelHeader}
                  onPress={() => setBbbExpanded(!bbbExpanded)}
                  activeOpacity={0.7}
                >
                  <Text style={styles.extrasPanelTitle}>🎯 Bingo Bango Bongo</Text>
                  <Text style={styles.extrasPanelToggle}>{bbbExpanded ? '▾' : '▸'}</Text>
                </TouchableOpacity>
                
                {bbbExpanded && (
                  <ScrollView style={styles.extrasPanelContent} nestedScrollEnabled>
                    {Array(18).fill(null).map((_, hole) => {
                      const bbbState = bbbHoles[hole];
                      const bingoPlayer = bbbState?.bingoPlayerId 
                        ? setup.players.find(p => p.id === bbbState.bingoPlayerId)
                        : null;
                      const bangoPlayer = bbbState?.bangoPlayerId 
                        ? setup.players.find(p => p.id === bbbState.bangoPlayerId)
                        : null;
                      const bongoPlayer = bbbState?.bongoPlayerId 
                        ? setup.players.find(p => p.id === bbbState.bongoPlayerId)
                        : null;
                      
                      return (
                        <View key={hole} style={styles.bbbRow}>
                          <Text style={styles.bbbHoleNum}>H{hole + 1}</Text>
                          <TouchableOpacity 
                            style={styles.bbbBtn}
                            onPress={() => cyclePlayer(hole, 'bingoPlayerId')}
                          >
                            <Text style={styles.bbbBtnLabel}>Bingo</Text>
                            <Text style={styles.bbbBtnValue}>{bingoPlayer?.name ?? '—'}</Text>
                          </TouchableOpacity>
                          <TouchableOpacity 
                            style={styles.bbbBtn}
                            onPress={() => cyclePlayer(hole, 'bangoPlayerId')}
                          >
                            <Text style={styles.bbbBtnLabel}>Bango</Text>
                            <Text style={styles.bbbBtnValue}>{bangoPlayer?.name ?? '—'}</Text>
                          </TouchableOpacity>
                          <TouchableOpacity 
                            style={styles.bbbBtn}
                            onPress={() => cyclePlayer(hole, 'bongoPlayerId')}
                          >
                            <Text style={styles.bbbBtnLabel}>Bongo</Text>
                            <Text style={styles.bbbBtnValue}>{bongoPlayer?.name ?? '—'}</Text>
                          </TouchableOpacity>
                        </View>
                      );
                    })}
                  </ScrollView>
                )}
              </LinearGradient>
            )}

            {/* Snake Panel */}
            {hasSnake && (
              <LinearGradient
                colors={['#212121', '#141414']}
                style={styles.extrasPanel}
              >
                <View style={styles.cardHighlight} />
                <TouchableOpacity 
                  style={styles.extrasPanelHeader}
                  onPress={() => setSnakeExpanded(!snakeExpanded)}
                  activeOpacity={0.7}
                >
                  <Text style={styles.extrasPanelTitle}>
                    🐍 Snake {getSnakeHolder() 
                      ? `(${setup.players.find(p => p.id === getSnakeHolder())?.name ?? '?'} holds)` 
                      : '(no holder)'}
                  </Text>
                  <Text style={styles.extrasPanelToggle}>{snakeExpanded ? '▾' : '▸'}</Text>
                </TouchableOpacity>
                
                {snakeExpanded && (
                  <ScrollView style={styles.extrasPanelContent} nestedScrollEnabled>
                    {Array(18).fill(null).map((_, hole) => {
                      const snakeState = snakeHoles[hole];
                      
                      return (
                        <View key={hole} style={styles.snakeRow}>
                          <Text style={styles.snakeHoleNum}>H{hole + 1}</Text>
                          <Text style={styles.snakeLabel}>3-putt:</Text>
                          <View style={styles.snakeCheckboxes}>
                            {setup.players.map(p => {
                              const isThreePutt = snakeState?.threeputters.includes(p.id) ?? false;
                              return (
                                <TouchableOpacity
                                  key={p.id}
                                  style={[styles.snakeCheckbox, isThreePutt && styles.snakeCheckboxActive]}
                                  onPress={() => toggleThreePutt(hole, p.id)}
                                >
                                  <Text style={[
                                    styles.snakeCheckboxText,
                                    isThreePutt && styles.snakeCheckboxTextActive
                                  ]}>
                                    {p.name.slice(0, 3)}
                                  </Text>
                                </TouchableOpacity>
                              );
                            })}
                          </View>
                        </View>
                      );
                    })}
                  </ScrollView>
                )}
              </LinearGradient>
            )}
          </View>
        )}
      </ScrollView>

      {/* ─── Live Game Status Bar ─────────────────────────────────────────────── */}
      {!isPreview && liveStatus.length > 0 && (
        <LinearGradient
          colors={['#0d0d0d', '#060606']}
          style={styles.liveStatusBar}
        >
          <View style={styles.liveStatusHighlight} />
          <Text style={styles.liveStatusHeader}>ACTIVE GAMES</Text>
          <ScrollView 
            style={styles.liveStatusScroll} 
            showsVerticalScrollIndicator={false}
            nestedScrollEnabled
          >
            {liveStatus.map((game, gi) => (
              <View key={gi} style={styles.liveStatusRow}>
                <Text style={styles.liveStatusLabel}>{game.label}:</Text>
                <View style={styles.liveStatusLines}>
                  {game.lines.map((line, li) => (
                    <Text
                      key={li}
                      style={[
                        styles.liveStatusText,
                        line.color === 'green' && styles.liveStatusGreen,
                        line.color === 'red' && styles.liveStatusRed,
                        line.color === 'yellow' && styles.liveStatusYellow,
                      ]}
                    >
                      {line.text}
                    </Text>
                  ))}
                </View>
              </View>
            ))}
          </ScrollView>
        </LinearGradient>
      )}

      {/* Footer */}
      <View style={styles.footer}>
        {isPreview ? (
          <TouchableOpacity
            style={styles.calcBtnOuter}
            onPress={() => router.replace('/setup')}
            activeOpacity={0.85}
          >
            <LinearGradient
              colors={['#52ff20', '#2dcc08', '#1fa005']}
              locations={[0, 0.6, 1]}
              start={{ x: 0.5, y: 0 }}
              end={{ x: 0.5, y: 1 }}
              style={styles.calcBtnGrad}
            >
              <View style={styles.btnSpecular} />
              <View style={styles.btnEdgeTop} />
              <View style={styles.btnEdgeBottom} />
              <View
                style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
              />
              <Text style={styles.calcBtnText}>Start a Real Game →</Text>
            </LinearGradient>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity style={styles.calcBtnOuter} onPress={handleCalculate} activeOpacity={0.85}>
            <LinearGradient
              colors={['#52ff20', '#2dcc08', '#1fa005']}
              locations={[0, 0.6, 1]}
              start={{ x: 0.5, y: 0 }}
              end={{ x: 0.5, y: 1 }}
              style={styles.calcBtnGrad}
            >
              <View style={styles.btnSpecular} />
              <View style={styles.btnEdgeTop} />
              <View style={styles.btnEdgeBottom} />
              <View
                style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
              />
              <Text style={styles.calcBtnText}>Calculate Payout →</Text>
            </LinearGradient>
          </TouchableOpacity>
        )}
      </View>
    </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  bgFull: { flex: 1 },
  bgOverlay: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.62)' },
  container: { flex: 1, width: '100%' },
  mainScroll: { flex: 1, width: '100%' },

  // Radial center glow
  centerGlow: {
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
    zIndex: 0,
  },

  // Card highlight (top edge)
  cardHighlight: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.07)',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    zIndex: 1,
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

  // Preview mode banner
  previewBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: '#39FF14',
    paddingHorizontal: 12,
    paddingVertical: 10,
    overflow: 'hidden',
  },
  previewIcon: { fontSize: 20, marginRight: 10 },
  previewTextContainer: { flex: 1 },
  previewTitle: { color: '#39FF14', fontWeight: '700', fontSize: 14 },
  previewSubtitle: { color: '#888', fontSize: 11, marginTop: 1 },
  previewCTAOuter: {
    borderRadius: 8,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.4,
    shadowRadius: 8,
  },
  previewCTAInner: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
  },
  previewCTAText: { color: '#000', fontWeight: '800', fontSize: 13 },

  grid: { flexDirection: 'row', width: '100%' },

  stickyCol: { zIndex: 10 },

  rowAlt: { backgroundColor: '#0f0f0f' },

  cell: {
    justifyContent: 'center',
    alignItems: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderRightWidth: StyleSheet.hairlineWidth,
    borderColor: '#242424',
  },

  // Header (hole numbers)
  hdrCell: { borderColor: '#242424' },
  hdrText: { color: '#fff', fontWeight: '700', fontSize: 12 },

  // OUT / IN / TOT headers
  sumHdrCell: {},
  sumHdrText: { color: '#39FF14', fontWeight: '800', fontSize: 11, letterSpacing: 0.3 },

  // Par label on sticky col
  parLabelCell: { backgroundColor: '#161616' },
  parLabelText: { color: '#444', fontWeight: '700', fontSize: 11, letterSpacing: 1.5, textTransform: 'uppercase' },

  // Player name cells (sticky)
  nameCell: { paddingHorizontal: 6, alignItems: 'flex-start', borderRightWidth: 1, borderRightColor: '#1e1e1e' },
  nameText: { color: '#fff', fontWeight: '600', fontSize: 13 },
  tmText: { color: '#39FF14', fontSize: 9, fontWeight: '700', marginTop: 1 },
  hcpText: { color: '#888', fontSize: 9, fontWeight: '600' },

  // Par cells
  parCell: { backgroundColor: '#161616' },
  parText: { color: '#888', fontSize: 13, fontWeight: '500' },
  hammerCell: { backgroundColor: '#070707' },
  hammerText: { color: '#333', fontSize: 11, fontWeight: '700' },
  hammerTextActive: { color: '#39FF14' },

  // OUT/IN/TOT value cells
  sumCell: { backgroundColor: '#0f0f0f' },
  sumText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  totText: { fontWeight: '800' },
  totWin: { color: '#39FF14' },
  totLose: { color: '#ff4444' },

  // Score cells
  scoreCell: {},

  dotBase: {
    width: 20,
    height: 20,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
  },
  dotPar: { backgroundColor: '#333' },
  dotUnder: { 
    backgroundColor: '#39FF14',
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.7,
    shadowRadius: 5,
  },
  dotBogey: { 
    backgroundColor: '#ff4444',
    shadowColor: '#ff4444',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 4,
  },
  dotDouble: { 
    backgroundColor: '#cc2222',
    shadowColor: '#cc2222',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 4,
  },

  scoreText: { fontSize: 12, fontWeight: '700', color: '#fff' },
  stUnder: { color: '#000' },
  stOver: { color: '#fff' },
  emptyDot: { color: '#333', fontSize: 18 },

  // Modal
  modalBg: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.85)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalCard: {
    width: 240,
  },
  modalCardInner: {
    padding: 24,
    alignItems: 'center',
  },
  modalTitle: { color: '#fff', fontWeight: '600', fontSize: 15, marginBottom: 16, letterSpacing: 0.3 },
  modalInput: {
    backgroundColor: '#040a02',
    borderWidth: 2,
    borderColor: '#39FF14',
    borderRadius: 14,
    fontSize: 44,
    fontWeight: '800',
    color: '#39FF14',
    width: 130,
    textAlign: 'center',
    paddingVertical: 10,
    marginBottom: 20,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.6,
    shadowRadius: 10,
  },
  modalBtns: { flexDirection: 'row', gap: 10, width: '100%' },
  modalCancelOuter: {
    flex: 1,
    borderRadius: 14,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.5,
    shadowRadius: 6,
  },
  modalCancelInner: {
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: 14,
    borderWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.08)',
    borderColor: '#2a2a2a',
  },
  modalCancelText: { color: '#888', fontWeight: '600', fontSize: 16 },
  modalConfirmOuter: {
    flex: 1,
    borderRadius: 14,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.55,
    shadowRadius: 20,
    elevation: 14,
  },
  modalConfirmInner: {
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: 14,
    overflow: 'hidden',
    position: 'relative',
  },
  modalConfirmText: { color: '#000', fontWeight: '800', fontSize: 16, zIndex: 1 },

  // ─── Game Extras ──────────────────────────────────────────────────────────
  extrasContainer: {
    padding: 12,
    gap: 12,
  },
  extrasPanel: {
    borderRadius: 16,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 12,
    elevation: 8,
  },
  extrasPanelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 12,
    backgroundColor: 'rgba(0,0,0,0.2)',
  },
  extrasPanelTitle: {
    color: '#39FF14',
    fontWeight: '700',
    fontSize: 14,
  },
  extrasPanelToggle: {
    color: '#555',
    fontSize: 16,
  },
  extrasPanelContent: {
    maxHeight: 200,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },

  // Wolf warning (when < 3 players)
  wolfWarning: {
    padding: 12,
    backgroundColor: '#1a1200',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#554400',
    marginVertical: 8,
    marginHorizontal: 16,
    alignItems: 'center',
  },
  wolfWarningText: {
    color: '#aa8800',
    fontSize: 13,
    fontWeight: '600',
  },

  // Wolf panel styles
  wolfRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#242424',
  },
  wolfHoleNum: {
    color: '#555',
    fontSize: 12,
    fontWeight: '700',
    width: 28,
  },
  wolfLabel: {
    color: '#888',
    fontSize: 11,
    marginRight: 4,
  },
  wolfName: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
    marginRight: 10,
    minWidth: 50,
  },
  wolfPartnerPicker: {
    flexDirection: 'row',
    flex: 1,
    gap: 4,
  },
  wolfPartnerBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    backgroundColor: '#0f0f0f',
    borderWidth: 1,
    borderColor: '#242424',
  },
  wolfPartnerBtnActive: {
    backgroundColor: '#39FF14',
    borderColor: '#39FF14',
  },
  wolfPartnerBtnText: {
    color: '#888',
    fontSize: 10,
    fontWeight: '600',
  },
  wolfPartnerBtnTextActive: {
    color: '#000',
  },

  // BBB panel styles
  bbbRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#242424',
    gap: 6,
  },
  bbbHoleNum: {
    color: '#555',
    fontSize: 12,
    fontWeight: '700',
    width: 28,
  },
  bbbBtn: {
    flex: 1,
    backgroundColor: '#0f0f0f',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#242424',
    paddingVertical: 4,
    paddingHorizontal: 6,
    alignItems: 'center',
  },
  bbbBtnLabel: {
    color: '#888',
    fontSize: 9,
    fontWeight: '600',
  },
  bbbBtnValue: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '700',
  },

  // Snake panel styles
  snakeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#242424',
  },
  snakeHoleNum: {
    color: '#555',
    fontSize: 12,
    fontWeight: '700',
    width: 28,
  },
  snakeLabel: {
    color: '#888',
    fontSize: 11,
    marginRight: 8,
  },
  snakeCheckboxes: {
    flexDirection: 'row',
    flex: 1,
    gap: 6,
  },
  snakeCheckbox: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
    backgroundColor: '#0f0f0f',
    borderWidth: 1,
    borderColor: '#242424',
  },
  snakeCheckboxActive: {
    backgroundColor: '#ff4444',
    borderColor: '#ff4444',
  },
  snakeCheckboxText: {
    color: '#888',
    fontSize: 10,
    fontWeight: '600',
  },
  snakeCheckboxTextActive: {
    color: '#fff',
  },

  // ─── Live Status Bar ───────────────────────────────────────────────────────
  liveStatusBar: {
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.04)',
    paddingHorizontal: 16,
    paddingVertical: 14,
    maxHeight: 200,
    overflow: 'hidden',
  },
  liveStatusHighlight: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.04)',
  },
  liveStatusHeader: {
    color: '#444',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1.5,
    marginBottom: 10,
    textTransform: 'uppercase',
  },
  liveStatusScroll: {
    flexGrow: 0,
  },
  liveStatusRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 10,
    flexWrap: 'wrap',
  },
  liveStatusLabel: {
    color: '#888',
    fontSize: 14,
    fontWeight: '600',
    marginRight: 8,
    minWidth: 90,
  },
  liveStatusLines: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    flex: 1,
    gap: 10,
  },
  liveStatusText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  liveStatusGreen: {
    color: '#39FF14',
  },
  liveStatusRed: {
    color: '#ff4444',
  },
  liveStatusYellow: {
    color: '#FFD700',
  },

  // Footer
  footer: {
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: Platform.OS === 'ios' ? 32 : 16,
    backgroundColor: '#050505',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#242424',
    width: '100%',
  },
  calcBtnOuter: {
    borderRadius: 14,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.55,
    shadowRadius: 20,
    elevation: 14,
  },
  calcBtnGrad: {
    borderRadius: 14,
    paddingVertical: 18,
    alignItems: 'center',
    overflow: 'hidden',
    position: 'relative',
  },
  calcBtnText: { color: '#000', fontWeight: '900', fontSize: 18, letterSpacing: 0.3, zIndex: 1 },
});
