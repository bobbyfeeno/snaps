import { useLocalSearchParams, useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
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
import { calcAllGames, calcLiveStatus, GameExtras, LiveStatus, LiveStatusLine } from '../lib/gameEngines';
import { BBBHoleState, GameMode, GameSetup, MultiGameResults, NassauConfig, PressMatch, SnakeHoleState, WolfHoleState } from '../types';
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
  const hasSnake = hasGame(activeGameModes, 'snake');
  const hasExtras = hasWolf || hasBBB || hasSnake;

  return (
    <View style={styles.container}>
      {/* Preview mode banner */}
      {isPreview && (
        <View style={styles.previewBanner}>
          <Text style={styles.previewIcon}>👀</Text>
          <View style={styles.previewTextContainer}>
            <Text style={styles.previewTitle}>Preview Mode</Text>
            <Text style={styles.previewSubtitle}>Sample data — scores are locked</Text>
          </View>
          <TouchableOpacity
            style={styles.previewCTA}
            onPress={() => router.replace('/setup')}
            activeOpacity={0.8}
          >
            <Text style={styles.previewCTAText}>Start Game</Text>
          </TouchableOpacity>
        </View>
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

      <ScrollView style={styles.mainScroll} bounces={false}>
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
                <Text style={styles.nameText} numberOfLines={1}>
                  {hasSnake && getSnakeHolder() === player.id ? '🐍 ' : ''}{player.name}
                </Text>
                <Text style={styles.tmText}>TM {player.taxMan}</Text>
                {useHandicaps && player.handicap !== undefined && (
                  <Text style={styles.hcpText}>HCP {player.handicap}</Text>
                )}
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
                          style={[styles.cell, styles.scoreCell, { width: CELL_W }]}
                        >
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
            {hasWolf && (
              <View style={styles.extrasPanel}>
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
              </View>
            )}

            {/* BBB Panel */}
            {hasBBB && (
              <View style={styles.extrasPanel}>
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
              </View>
            )}

            {/* Snake Panel */}
            {hasSnake && (
              <View style={styles.extrasPanel}>
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
              </View>
            )}
          </View>
        )}
      </ScrollView>

      {/* ─── Live Game Status Bar ─────────────────────────────────────────────── */}
      {!isPreview && liveStatus.length > 0 && (
        <View style={styles.liveStatusBar}>
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
        </View>
      )}

      {/* Footer */}
      <View style={styles.footer}>
        {isPreview ? (
          <TouchableOpacity
            style={styles.calcBtn}
            onPress={() => router.replace('/setup')}
            activeOpacity={0.8}
          >
            <Text style={styles.calcBtnText}>Start a Real Game →</Text>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity style={styles.calcBtn} onPress={handleCalculate} activeOpacity={0.8}>
            <Text style={styles.calcBtnText}>Calculate Payout →</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  mainScroll: { flex: 1 },

  // Preview mode banner
  previewBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a2f1a',
    borderBottomWidth: 1,
    borderBottomColor: '#39FF14',
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  previewIcon: { fontSize: 20, marginRight: 10 },
  previewTextContainer: { flex: 1 },
  previewTitle: { color: '#39FF14', fontWeight: '700', fontSize: 14 },
  previewSubtitle: { color: '#5a8a5a', fontSize: 11, marginTop: 1 },
  previewCTA: {
    backgroundColor: '#39FF14',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
  },
  previewCTAText: { color: '#000', fontWeight: '800', fontSize: 13 },

  grid: { flexDirection: 'row' },

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
  hcpText: { color: '#888', fontSize: 9, fontWeight: '600' },

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

  // ─── Game Extras ──────────────────────────────────────────────────────────
  extrasContainer: {
    padding: 12,
    gap: 12,
  },
  extrasPanel: {
    backgroundColor: '#141414',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2a2a2a',
    overflow: 'hidden',
  },
  extrasPanelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 12,
    backgroundColor: '#1a2a1a',
  },
  extrasPanelTitle: {
    color: '#39FF14',
    fontWeight: '700',
    fontSize: 14,
  },
  extrasPanelToggle: {
    color: '#5a8a5a',
    fontSize: 16,
  },
  extrasPanelContent: {
    maxHeight: 200,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },

  // Wolf panel styles
  wolfRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#2a2a2a',
  },
  wolfHoleNum: {
    color: '#666',
    fontSize: 12,
    fontWeight: '700',
    width: 28,
  },
  wolfLabel: {
    color: '#5a8a5a',
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
    backgroundColor: '#0d1f0d',
    borderWidth: 1,
    borderColor: '#2a4a2a',
  },
  wolfPartnerBtnActive: {
    backgroundColor: '#39FF14',
    borderColor: '#39FF14',
  },
  wolfPartnerBtnText: {
    color: '#5a8a5a',
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
    borderBottomColor: '#2a2a2a',
    gap: 6,
  },
  bbbHoleNum: {
    color: '#666',
    fontSize: 12,
    fontWeight: '700',
    width: 28,
  },
  bbbBtn: {
    flex: 1,
    backgroundColor: '#0d1f0d',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    paddingVertical: 4,
    paddingHorizontal: 6,
    alignItems: 'center',
  },
  bbbBtnLabel: {
    color: '#5a8a5a',
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
    borderBottomColor: '#2a2a2a',
  },
  snakeHoleNum: {
    color: '#666',
    fontSize: 12,
    fontWeight: '700',
    width: 28,
  },
  snakeLabel: {
    color: '#5a8a5a',
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
    backgroundColor: '#0d1f0d',
    borderWidth: 1,
    borderColor: '#2a4a2a',
  },
  snakeCheckboxActive: {
    backgroundColor: '#ff5555',
    borderColor: '#ff5555',
  },
  snakeCheckboxText: {
    color: '#5a8a5a',
    fontSize: 10,
    fontWeight: '600',
  },
  snakeCheckboxTextActive: {
    color: '#fff',
  },

  // ─── Live Status Bar ───────────────────────────────────────────────────────
  liveStatusBar: {
    backgroundColor: '#0a0a0a',
    borderTopWidth: 1,
    borderTopColor: '#2a2a2a',
    paddingHorizontal: 16,
    paddingVertical: 14,
    maxHeight: 200,
  },
  liveStatusHeader: {
    color: '#666',
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 1.2,
    marginBottom: 10,
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
    color: '#ff5555',
  },
  liveStatusYellow: {
    color: '#FFD700',
  },

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
