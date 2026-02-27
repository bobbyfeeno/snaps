import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import {
  ImageBackground,
  KeyboardAvoidingView,
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
import { getSavedPlayers } from '../lib/storage';
import { BestBallConfig, GameConfig, GameMode, GameSetup, NassauConfig, Player, SavedPlayer } from '../types';

const MAX_PLAYERS = 6;

function generateId() {
  return Math.random().toString(36).slice(2, 9);
}

function createPlayer(): Player {
  return { id: generateId(), name: '', taxMan: 90 };
}

// Simple global store — no backend, no context needed for this flow
export let gameSetup: GameSetup | null = null;

export function resetGameSetup() {
  gameSetup = null;
}

// ─── Game definitions ───────────────────────────────────────────────────────

interface GameDef {
  mode: GameMode;
  name: string;
  description: string;
  inputLabel: string;
  defaultAmount: number;
  minPlayers?: number;
}

const GAME_DEFS: GameDef[] = [
  {
    mode: 'scorecard',
    name: 'Keep Score',
    description: 'Track scores and see a final leaderboard. No betting required.',
    inputLabel: '',
    defaultAmount: 0,
  },
  {
    mode: 'taxman',
    name: 'Tax Man',
    description: 'Beat your target score. Losers pay every winner.',
    inputLabel: 'Tax Amount $',
    defaultAmount: 10,
  },
  {
    mode: 'nassau',
    name: 'Nassau',
    description: '3 bets: front 9, back 9, full 18.',
    inputLabel: 'Bet per leg $',
    defaultAmount: 5,
  },
  {
    mode: 'skins',
    name: 'Skins',
    description: 'Win a hole outright — ties carry over.',
    inputLabel: '$ per skin',
    defaultAmount: 5,
  },
  {
    mode: 'wolf',
    name: 'Wolf',
    description: 'Rotating Wolf picks a partner or goes alone.',
    inputLabel: '$ per hole',
    defaultAmount: 2,
    minPlayers: 3,
  },
  {
    mode: 'bingo-bango-bongo',
    name: 'Bingo Bango Bongo',
    description: '3 points per hole: first on, closest, first in.',
    inputLabel: '$ per point',
    defaultAmount: 1,
  },
  {
    mode: 'snake',
    name: 'Snake',
    description: '3-putt and you hold the snake. Holder at 18 pays all.',
    inputLabel: 'Snake amount $',
    defaultAmount: 10,
  },
  {
    mode: 'vegas',
    name: 'Vegas',
    description: '2v2 teams. Combine scores each hole — lowest number wins the diff.',
    inputLabel: '$ per point',
    defaultAmount: 1,
    minPlayers: 4,
  },
  {
    mode: 'best-ball',
    name: 'Best Ball',
    description: '2v2 teams. Each team takes their best score per hole.',
    inputLabel: '$ per hole / stroke',
    defaultAmount: 5,
    minPlayers: 4,
  },
];

// ─── iOS-style glossy icon definitions (glass sphere look) ─────────────────

// Shared green active state — all selected icons use brand neon green
const ACTIVE_COLORS: [string, string, string] = ['#0A4000', '#1AAA00', '#3EFF18'];
const ACTIVE_SHADOW = '#39FF14';

const ICON_DEFS: Record<string, {
  emoji: string;
  activeColors: [string, string, string];
  inactiveColors: [string, string, string];
  shadowColor: string;
}> = {
  scorecard:        { emoji: '📊', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  taxman:           { emoji: '💰', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  nassau:           { emoji: '🏆', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  skins:            { emoji: '💵', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  wolf:             { emoji: '🐺', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  'bingo-bango-bongo': { emoji: '🎯', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  snake:            { emoji: '🐍', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  vegas:            { emoji: '🎰', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
  'best-ball':      { emoji: '⚔️', activeColors: ACTIVE_COLORS, inactiveColors: ['#000000','#050505','#0a0a0a'], shadowColor: ACTIVE_SHADOW },
};

// ─── GameIcon Component ─────────────────────────────────────────────────────

function GameIcon({ game, isActive, onPress }: {
  game: GameDef;
  isActive: boolean;
  onPress: () => void;
}) {
  const def = ICON_DEFS[game.mode];

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.75} style={styles.gameIconWrapper}>
      {/* Outer container with deep shadow */}
      <View style={[
        styles.gameIconOuter,
        { shadowColor: isActive ? def.shadowColor : '#000' },
        isActive ? styles.gameIconOuterActive : styles.gameIconOuterInactive,
      ]}>
        {/* === LAYER 1: Base face gradient (top-bright → rich → dark-bottom) === */}
        <LinearGradient
          colors={isActive
            ? [def.activeColors[2], def.activeColors[1], def.activeColors[0]]
            : ['#181818', '#0d0d0d', '#000000']}
          locations={[0, 0.5, 1]}
          start={{ x: 0.5, y: 0 }}
          end={{ x: 0.5, y: 1 }}
          style={styles.gameIconGrad}
        >
          {/* === LAYER 2: Side lighting (left bright → center → right dark) === */}
          <LinearGradient
            colors={['rgba(255,255,255,0.10)', 'rgba(255,255,255,0.0)', 'rgba(0,0,0,0.18)']}
            locations={[0, 0.4, 1]}
            start={{ x: 0, y: 0.5 }}
            end={{ x: 1, y: 0.5 }}
            style={StyleSheet.absoluteFill}
          />

          {/* === LAYER 3: Primary specular — soft oval top-center === */}
          <LinearGradient
            colors={['rgba(255,255,255,0.60)', 'rgba(255,255,255,0.18)', 'rgba(255,255,255,0.0)']}
            locations={[0, 0.45, 1]}
            start={{ x: 0.5, y: 0 }}
            end={{ x: 0.5, y: 1 }}
            style={styles.iconSpecularPrimary}
          />

          {/* === LAYER 4: Secondary specular — small bright hot spot === */}
          <View style={styles.iconSpecularDot} />

          {/* === LAYER 5: Bottom inner shadow === */}
          <LinearGradient
            colors={['rgba(0,0,0,0.0)', 'rgba(0,0,0,0.40)']}
            start={{ x: 0.5, y: 0 }}
            end={{ x: 0.5, y: 1 }}
            style={styles.iconBottomShadow}
          />

          {/* === LAYER 6: Top edge highlight === */}
          <View style={styles.iconTopEdge} />

          {/* === Emoji (floats above all layers) === */}
          <Text style={styles.gameIconEmoji}>{def.emoji}</Text>

          {/* === Checkmark === */}
          {isActive && (
            <View style={styles.gameIconCheck}>
              <Text style={styles.gameIconCheckText}>✓</Text>
            </View>
          )}
        </LinearGradient>
      </View>

      <Text style={[styles.gameIconLabel, isActive && styles.gameIconLabelActive]}>
        {game.name}
      </Text>
    </TouchableOpacity>
  );
}

export default function SetupScreen() {
  const router = useRouter();
  const [step, setStep] = useState<1 | 2>(1);
  const [players, setPlayers] = useState<Player[]>([createPlayer(), createPlayer()]);
  const nameRefs = useRef<(TextInput | null)[]>([]);
  const stepTwoScrollRef = useRef<ScrollView>(null);
  
  // Game selection state
  const [activeGames, setActiveGames] = useState<Set<GameMode>>(new Set(['scorecard']));
  const [gameAmounts, setGameAmounts] = useState<Record<GameMode, string>>({
    scorecard: '0',
    taxman: '10',
    nassau: '5',
    skins: '5',
    wolf: '2',
    'bingo-bango-bongo': '1',
    snake: '10',
    vegas: '1',
    'best-ball': '5',
  });
  const [nassauMode, setNassauMode] = useState<'stroke' | 'match'>('stroke');
  const [nassauPress, setNassauPress] = useState<'none' | 'auto'>('none');
  const [nassauHandicaps, setNassauHandicaps] = useState(false);
  const [nassauHammer, setNassauHammer] = useState(false);
  // Vegas options
  const [vegasFlipBird, setVegasFlipBird] = useState(true);
  const [vegasHammer, setVegasHammer] = useState(false);
  // Best Ball options
  const [bestBallMode, setBestBallMode] = useState<'stroke' | 'match'>('stroke');
  // Team assignment: player ID → 'A' | 'B' (shared by Vegas + Best Ball)
  const [teamAssignment, setTeamAssignment] = useState<Record<string, 'A' | 'B'>>({});

  // Custom alert modal state
  const [alertMsg, setAlertMsg] = useState<{ title: string; body: string } | null>(null);

  // Saved players state
  const [savedPlayers, setSavedPlayers] = useState<SavedPlayer[]>([]);

  useEffect(() => {
    if (step === 2) {
      getSavedPlayers().then(setSavedPlayers).catch(() => {});
    }
  }, [step]);

  function quickAddPlayer(sp: SavedPlayer) {
    // Find first empty slot
    const emptySlot = players.find(p => p.name === '');
    if (emptySlot) {
      setPlayers(prev =>
        prev.map(p =>
          p.id === emptySlot.id
            ? { ...p, name: sp.name, taxMan: sp.taxMan, handicap: sp.handicap }
            : p
        )
      );
    } else if (players.length < MAX_PLAYERS) {
      // Add new player with saved data
      setPlayers(prev => [
        ...prev,
        { id: generateId(), name: sp.name, taxMan: sp.taxMan, handicap: sp.handicap },
      ]);
    }
  }

  function showAlert(title: string, body: string) {
    setAlertMsg({ title, body });
  }

  // ─── Step 1: Game Selection ────────────────────────────────────────────────

  const hasTaxMan = activeGames.has('taxman');

  function handleNextStep() {
    // Validation: at least one game selected
    if (activeGames.size === 0) {
      showAlert('No Games Selected', 'Select at least one game to play.');
      return;
    }

    // Wolf player check happens at Start Round

    setStep(2);
  }

  // ─── Step 2: Player Management ────────────────────────────────────────────

  function addPlayer() {
    if (players.length < MAX_PLAYERS) {
      setPlayers(prev => [...prev, createPlayer()]);
      setTimeout(() => stepTwoScrollRef.current?.scrollToEnd({ animated: true }), 100);
      setTimeout(() => stepTwoScrollRef.current?.scrollToEnd({ animated: true }), 350);
    }
  }

  function removePlayer(id: string) {
    if (players.length > 1) {
      setPlayers(prev => prev.filter(p => p.id !== id));
    }
  }

  function updateName(id: string, name: string) {
    setPlayers(prev => prev.map(p => (p.id === id ? { ...p, name } : p)));
  }

  function updateTaxMan(id: string, val: string) {
    const n = parseInt(val, 10);
    setPlayers(prev =>
      prev.map(p => (p.id === id ? { ...p, taxMan: isNaN(n) ? 0 : n } : p))
    );
  }

  function updateHandicap(id: string, val: string) {
    const n = parseInt(val, 10);
    setPlayers(prev =>
      prev.map(p => (p.id === id ? { ...p, handicap: isNaN(n) ? undefined : Math.min(36, Math.max(0, n)) } : p))
    );
  }

  // ─── Game Toggle ──────────────────────────────────────────────────────────

  function toggleGame(mode: GameMode) {
    setActiveGames(prev => {
      const next = new Set(prev);
      if (next.has(mode)) {
        next.delete(mode);
      } else {
        next.add(mode);
      }
      return next;
    });
  }

  function updateGameAmount(mode: GameMode, val: string) {
    setGameAmounts(prev => ({ ...prev, [mode]: val }));
  }

  function handleStart() {
    // Validate players
    const filledPlayers = players.filter(p => p.name.trim());
    const keepScoreOnly = activeGames.size === 1 && activeGames.has('scorecard');
    const minPlayers = keepScoreOnly ? 1 : 2;
    if (filledPlayers.length < minPlayers) {
      showAlert(
        'Need More Players',
        keepScoreOnly ? 'Enter your name to start.' : 'Add at least 2 players with names.',
      );
      return;
    }

    for (const p of filledPlayers) {
      if (hasTaxMan && (p.taxMan <= 0 || p.taxMan > 200)) {
        showAlert('Invalid Tax Man', `"${p.name}" needs a valid Tax Man score (1–200).`);
        return;
      }
    }

    // Check Wolf player requirement
    if (activeGames.has('wolf') && filledPlayers.length < 3) {
      showAlert('Wolf Game Selected', '3 or more players must be added for the Wolf game.');
      return;
    }

    // Check Vegas player requirement
    if (activeGames.has('vegas') && filledPlayers.length < 4) {
      showAlert('Vegas Selected', 'Vegas requires exactly 4 players — 2 per team.');
      return;
    }
    if (activeGames.has('vegas')) {
      const teamAIds = filledPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'A').map(p => p.id);
      const teamBIds = filledPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'B').map(p => p.id);
      if (teamAIds.length < 1 || teamBIds.length < 1) {
        showAlert('Team Assignment', 'Assign at least 1 player to each team for Vegas.');
        return;
      }
    }

    // Check Best Ball player requirement
    if (activeGames.has('best-ball') && filledPlayers.length < 4) {
      showAlert('Best Ball Selected', 'Best Ball requires at least 4 players — 2 per team.');
      return;
    }
    if (activeGames.has('best-ball')) {
      const teamAIds = filledPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'A').map(p => p.id);
      const teamBIds = filledPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'B').map(p => p.id);
      if (teamAIds.length < 1 || teamBIds.length < 1) {
        showAlert('Team Assignment', 'Assign at least 1 player to each team for Best Ball.');
        return;
      }
    }

    // Validate all active game amounts (skip scorecard since it has no amount)
    for (const mode of activeGames) {
      if (mode === 'scorecard') continue; // scorecard has no bet amount
      const amount = parseFloat(gameAmounts[mode]);
      if (isNaN(amount) || amount <= 0) {
        const gameName = GAME_DEFS.find(g => g.mode === mode)?.name ?? mode;
        showAlert('Invalid Amount', `Enter a valid dollar amount for ${gameName}.`);
        return;
      }
    }

    // Use only players with names
    const finalPlayers = filledPlayers;

    // Build GameConfig array
    const games: GameConfig[] = [];
    for (const mode of activeGames) {
      const amount = parseFloat(gameAmounts[mode]);
      switch (mode) {
        case 'scorecard':
          games.push({ mode: 'scorecard', config: {} });
          break;
        case 'taxman':
          games.push({ mode: 'taxman', config: { taxAmount: amount } });
          break;
        case 'nassau':
          games.push({ mode: 'nassau', config: { betAmount: amount, mode: nassauMode, press: nassauPress, useHandicaps: nassauHandicaps, useHammer: nassauHammer } });
          break;
        case 'skins':
          games.push({ mode: 'skins', config: { betPerSkin: amount } });
          break;
        case 'wolf':
          games.push({ mode: 'wolf', config: { betPerHole: amount } });
          break;
        case 'bingo-bango-bongo':
          games.push({ mode: 'bingo-bango-bongo', config: { betPerPoint: amount } });
          break;
        case 'snake':
          games.push({ mode: 'snake', config: { snakeAmount: amount } });
          break;
        case 'vegas': {
          const teamAIds = finalPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'A').map(p => p.id);
          const teamBIds = finalPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'B').map(p => p.id);
          games.push({ mode: 'vegas', config: { betPerPoint: amount, flipBird: vegasFlipBird, useHammer: vegasHammer, teamA: teamAIds, teamB: teamBIds } });
          break;
        }
        case 'best-ball': {
          const teamAIds = finalPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'A').map(p => p.id);
          const teamBIds = finalPlayers.filter(p => (teamAssignment[p.id] ?? 'A') === 'B').map(p => p.id);
          games.push({ mode: 'best-ball', config: { mode: bestBallMode, betAmount: amount, teamA: teamAIds, teamB: teamBIds } });
          break;
        }
      }
    }

    gameSetup = { players: finalPlayers, games };
    router.push('/scores');
  }

  // ─── Render Step 1: Games ─────────────────────────────────────────────────

  if (step === 1) {
    return (
      <ImageBackground source={require('../assets/bg.png')} style={styles.bgFull} resizeMode="cover">
        <View style={styles.bgOverlay} />
        <KeyboardAvoidingView
          style={styles.flex}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
        <ScrollView
          style={styles.scroll}
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
        >
          {/* Radial center glow */}
          <View style={styles.centerGlow} pointerEvents="none" />

          {/* Step indicator */}
          <View style={styles.stepIndicator}>
            <LinearGradient
              colors={['#44ff18', '#28cc08']}
              style={styles.stepDotActive}
            >
              <View style={styles.stepDotHighlight} />
            </LinearGradient>
            <View style={styles.stepLine} />
            <LinearGradient
              colors={['#1a1a1a', '#111111']}
              style={styles.stepDot}
            />
          </View>

          {/* Header */}
          <View style={[styles.section, { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between' }]}>
            <View>
              <Text style={styles.sectionTitle}>Games</Text>
              <Text style={styles.sectionSubtitle}>Pick your games for this round</Text>
            </View>
            <TouchableOpacity onPress={() => router.push('/rules')} activeOpacity={0.7} style={{ paddingTop: 4 }}>
              <Text style={{ color: '#39FF14', fontSize: 13, fontWeight: '600' }}>📖 Rules</Text>
            </TouchableOpacity>
          </View>

          {/* Icon Grid */}
          <View style={styles.iconGrid}>
            {GAME_DEFS.map(game => (
              <GameIcon
                key={game.mode}
                game={game}
                isActive={activeGames.has(game.mode)}
                onPress={() => toggleGame(game.mode)}
              />
            ))}
          </View>

          {/* Config panel for active games */}
          {Array.from(activeGames).filter(m => m !== 'scorecard').length > 0 && (
            <BevelCard style={styles.configPanel}>
              <View style={styles.cardHighlight} />
              {Array.from(activeGames).filter(m => m !== 'scorecard').map(mode => (
                <View key={mode} style={styles.configRow}>
                  <Text style={styles.configLabel}>{GAME_DEFS.find(g => g.mode === mode)?.name}</Text>
                  <View style={styles.configRight}>
                    <Text style={styles.dollarSign}>$</Text>
                    <TextInput
                      style={styles.configAmountInput}
                      value={gameAmounts[mode as GameMode]}
                      onChangeText={v => updateGameAmount(mode as GameMode, v)}
                      keyboardType="numeric"
                      maxLength={4}
                      placeholder="0"
                      placeholderTextColor="#333"
                    />
                  </View>
                </View>
              ))}
              {/* Nassau-specific options */}
              {activeGames.has('nassau') && (
                <View style={styles.nassauOpts}>
                  {/* Stroke/Match Play toggle */}
                  <View style={styles.nassauModeRow}>
                    <TouchableOpacity
                      style={[
                        styles.pillBtn,
                        nassauMode === 'stroke' && styles.pillBtnActive,
                      ]}
                      onPress={() => setNassauMode('stroke')}
                      activeOpacity={0.7}
                    >
                      <View
                        style={[StyleSheet.absoluteFill, { borderRadius: 20, overflow: 'hidden' }]}
                      />
                      <Text style={[
                        styles.pillBtnText,
                        nassauMode === 'stroke' && styles.pillBtnTextActive,
                      ]}>Stroke Play</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={[
                        styles.pillBtn,
                        nassauMode === 'match' && styles.pillBtnActive,
                      ]}
                      onPress={() => setNassauMode('match')}
                      activeOpacity={0.7}
                    >
                      <View
                        style={[StyleSheet.absoluteFill, { borderRadius: 20, overflow: 'hidden' }]}
                      />
                      <Text style={[
                        styles.pillBtnText,
                        nassauMode === 'match' && styles.pillBtnTextActive,
                      ]}>Match Play</Text>
                    </TouchableOpacity>
                  </View>

                  {/* Press toggle - only show for match play */}
                  {nassauMode === 'match' && (
                    <View style={styles.nassauOptionRow}>
                      <Text style={styles.nassauOptionLabel}>Press</Text>
                      <View style={styles.nassauToggleGroup}>
                        <TouchableOpacity
                          style={[
                            styles.pillBtn,
                            nassauPress === 'none' && styles.pillBtnActive,
                          ]}
                          onPress={() => setNassauPress('none')}
                          activeOpacity={0.7}
                        >
                          <View
                            style={[StyleSheet.absoluteFill, { borderRadius: 20, overflow: 'hidden' }]}
                          />
                          <Text style={[
                            styles.pillBtnText,
                            nassauPress === 'none' && styles.pillBtnTextActive,
                          ]}>No Press</Text>
                        </TouchableOpacity>
                        <TouchableOpacity
                          style={[
                            styles.pillBtn,
                            nassauPress === 'auto' && styles.pillBtnActive,
                          ]}
                          onPress={() => setNassauPress('auto')}
                          activeOpacity={0.7}
                        >
                          <View
                            style={[StyleSheet.absoluteFill, { borderRadius: 20, overflow: 'hidden' }]}
                          />
                          <Text style={[
                            styles.pillBtnText,
                            nassauPress === 'auto' && styles.pillBtnTextActive,
                          ]}>Auto Press</Text>
                        </TouchableOpacity>
                      </View>
                    </View>
                  )}

                  {/* Handicaps toggle */}
                  <View style={styles.nassauOptionRow}>
                    <Text style={styles.nassauOptionLabel}>Handicaps</Text>
                    <View style={styles.nassauToggleGroup}>
                      <TouchableOpacity
                        style={[
                          styles.pillBtn,
                          !nassauHandicaps && styles.pillBtnActive,
                        ]}
                        onPress={() => setNassauHandicaps(false)}
                        activeOpacity={0.7}
                      >
                        <View
                          style={[StyleSheet.absoluteFill, { borderRadius: 20, overflow: 'hidden' }]}
                        />
                        <Text style={[
                          styles.pillBtnText,
                          !nassauHandicaps && styles.pillBtnTextActive,
                        ]}>Off</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[
                          styles.pillBtn,
                          nassauHandicaps && styles.pillBtnActive,
                        ]}
                        onPress={() => setNassauHandicaps(true)}
                        activeOpacity={0.7}
                      >
                        <View
                          style={[StyleSheet.absoluteFill, { borderRadius: 20, overflow: 'hidden' }]}
                        />
                        <Text style={[
                          styles.pillBtnText,
                          nassauHandicaps && styles.pillBtnTextActive,
                        ]}>On</Text>
                      </TouchableOpacity>
                    </View>
                  </View>

                  {/* Hammer toggle (Nassau) */}
                  <View style={styles.nassauOptionRow}>
                    <Text style={styles.nassauOptionLabel}>🔨 Hammer</Text>
                    <View style={styles.nassauToggleGroup}>
                      <TouchableOpacity
                        style={[styles.pillBtn, !nassauHammer && styles.pillBtnActive]}
                        onPress={() => setNassauHammer(false)}
                        activeOpacity={0.7}
                      >
                        <Text style={[styles.pillBtnText, !nassauHammer && styles.pillBtnTextActive]}>Off</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.pillBtn, nassauHammer && styles.pillBtnActive]}
                        onPress={() => setNassauHammer(true)}
                        activeOpacity={0.7}
                      >
                        <Text style={[styles.pillBtnText, nassauHammer && styles.pillBtnTextActive]}>On</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                </View>
              )}

              {/* Best Ball options */}
              {activeGames.has('best-ball') && (
                <View style={styles.nassauOpts}>
                  <View style={styles.nassauModeRow}>
                    <TouchableOpacity
                      style={[styles.pillBtn, bestBallMode === 'stroke' && styles.pillBtnActive]}
                      onPress={() => setBestBallMode('stroke')}
                      activeOpacity={0.7}
                    >
                      <Text style={[styles.pillBtnText, bestBallMode === 'stroke' && styles.pillBtnTextActive]}>Stroke Play</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={[styles.pillBtn, bestBallMode === 'match' && styles.pillBtnActive]}
                      onPress={() => setBestBallMode('match')}
                      activeOpacity={0.7}
                    >
                      <Text style={[styles.pillBtnText, bestBallMode === 'match' && styles.pillBtnTextActive]}>Match Play</Text>
                    </TouchableOpacity>
                  </View>
                  <View style={[styles.nassauOptionRow, { marginTop: 8, paddingTop: 8 }]}>
                    <Text style={[styles.nassauOptionLabel, { color: '#555', fontSize: 13 }]}>
                      {bestBallMode === 'stroke' ? '$ per stroke difference' : '$ per hole won'}
                    </Text>
                  </View>
                </View>
              )}

              {/* Vegas-specific options */}
              {activeGames.has('vegas') && (
                <View style={styles.nassauOpts}>
                  {/* Flip the Bird */}
                  <View style={styles.nassauOptionRow}>
                    <Text style={styles.nassauOptionLabel}>🐦 Flip the Bird</Text>
                    <View style={styles.nassauToggleGroup}>
                      <TouchableOpacity
                        style={[styles.pillBtn, !vegasFlipBird && styles.pillBtnActive]}
                        onPress={() => setVegasFlipBird(false)}
                        activeOpacity={0.7}
                      >
                        <Text style={[styles.pillBtnText, !vegasFlipBird && styles.pillBtnTextActive]}>Off</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.pillBtn, vegasFlipBird && styles.pillBtnActive]}
                        onPress={() => setVegasFlipBird(true)}
                        activeOpacity={0.7}
                      >
                        <Text style={[styles.pillBtnText, vegasFlipBird && styles.pillBtnTextActive]}>On</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                  {/* Vegas Hammer */}
                  <View style={styles.nassauOptionRow}>
                    <Text style={styles.nassauOptionLabel}>🔨 Hammer</Text>
                    <View style={styles.nassauToggleGroup}>
                      <TouchableOpacity
                        style={[styles.pillBtn, !vegasHammer && styles.pillBtnActive]}
                        onPress={() => setVegasHammer(false)}
                        activeOpacity={0.7}
                      >
                        <Text style={[styles.pillBtnText, !vegasHammer && styles.pillBtnTextActive]}>Off</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={[styles.pillBtn, vegasHammer && styles.pillBtnActive]}
                        onPress={() => setVegasHammer(true)}
                        activeOpacity={0.7}
                      >
                        <Text style={[styles.pillBtnText, vegasHammer && styles.pillBtnTextActive]}>On</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                </View>
              )}
            </BevelCard>
          )}

          {/* Validation message */}
          {activeGames.size === 0 && (
            <Text style={styles.validationHint}>Select at least one game</Text>
          )}

          {/* Bottom buttons */}
          <View style={styles.bottomBtns}>
            <TouchableOpacity style={styles.secondaryBtnOuter} onPress={() => router.back()} activeOpacity={0.7}>
              <LinearGradient
                colors={['#1e1e1e', '#141414']}
                style={styles.secondaryBtnInner}
              >
                <View style={styles.secondaryBtnHighlight} />
                <View
                  style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
                />
                <Text style={styles.secondaryBtnText}>Cancel</Text>
              </LinearGradient>
            </TouchableOpacity>
            <TouchableOpacity 
              style={[styles.primaryBtnOuter, activeGames.size === 0 && styles.primaryBtnDisabled]} 
              onPress={handleNextStep} 
              activeOpacity={0.85}
              disabled={Boolean(activeGames.size === 0)}
            >
              <LinearGradient
                colors={activeGames.size === 0 ? ['#1a3a0a', '#133005', '#0f2006'] : ['#52ff20', '#2dcc08', '#1fa005']}
                locations={[0, 0.6, 1]}
                start={{ x: 0.5, y: 0 }}
                end={{ x: 0.5, y: 1 }}
                style={styles.primaryBtnGrad}
              >
                {activeGames.size > 0 && <View style={styles.btnSpecular} />}
                <View style={styles.btnEdgeTop} />
                <View style={styles.btnEdgeBottom} />
                <View
                  style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
                />
                <Text style={styles.primaryBtnText}>Next →</Text>
              </LinearGradient>
            </TouchableOpacity>
          </View>
        </ScrollView>

        {/* Custom Alert Modal */}
        {alertMsg && (
          <Modal
            transparent
            animationType="fade"
            visible={!!alertMsg}
            onRequestClose={() => setAlertMsg(null)}
          >
            <View style={styles.alertOverlay}>
              <View style={styles.alertBox}>
                <View style={styles.alertHighlight} />
                <Text style={styles.alertTitle}>{alertMsg.title}</Text>
                <Text style={styles.alertBody}>{alertMsg.body}</Text>
                <TouchableOpacity
                  style={styles.alertBtn}
                  onPress={() => setAlertMsg(null)}
                  activeOpacity={0.8}
                >
                  <LinearGradient
                    colors={['#44ff18', '#28cc08']}
                    start={{ x: 0.5, y: 0 }}
                    end={{ x: 0.5, y: 1 }}
                    style={styles.alertBtnGrad}
                  >
                    <View
                      style={[StyleSheet.absoluteFill, { borderRadius: 12, overflow: 'hidden' }]}
                    />
                    <Text style={styles.alertBtnText}>Got it</Text>
                  </LinearGradient>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>
        )}
        </KeyboardAvoidingView>
      </ImageBackground>
    );
  }

  // ─── Render Step 2: Players ───────────────────────────────────────────────

  return (
    <ImageBackground source={require('../assets/bg.png')} style={styles.bgFull} resizeMode="cover">
      <View style={styles.bgOverlay} />
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
      <ScrollView
        ref={stepTwoScrollRef}
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        {/* Radial center glow */}
        <View style={styles.centerGlow} pointerEvents="none" />

        {/* Step indicator */}
        <View style={styles.stepIndicator}>
          <TouchableOpacity onPress={() => setStep(1)}>
            <LinearGradient
              colors={['#44ff18', '#28cc08']}
              style={styles.stepDotComplete}
            >
              <Text style={styles.stepCheck}>✓</Text>
            </LinearGradient>
          </TouchableOpacity>
          <View style={[styles.stepLine, styles.stepLineComplete]} />
          <LinearGradient
            colors={['#44ff18', '#28cc08']}
            style={styles.stepDotActive}
          >
            <View style={styles.stepDotHighlight} />
          </LinearGradient>
        </View>

        {/* Players */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Players</Text>
          <Text style={styles.sectionSubtitle}>
            {hasTaxMan ? 'Name + Tax Man score' : 'Add your players'}
          </Text>

          {/* Saved Players Quick-Add */}
          {savedPlayers.length > 0 && (
            <View style={styles.savedPlayersSection}>
              <Text style={styles.savedPlayersLabel}>SAVED PLAYERS</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                {savedPlayers.map(sp => (
                  <TouchableOpacity
                    key={sp.id}
                    style={styles.savedPlayerChip}
                    onPress={() => quickAddPlayer(sp)}
                    activeOpacity={0.7}
                  >
                    <Text style={styles.savedPlayerName}>{sp.name}</Text>
                    <Text style={styles.savedPlayerTM}>TM {sp.taxMan}</Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>
          )}

          {players.map((player, idx) => (
            <BevelCard key={player.id} style={styles.playerCard}>
              <View style={styles.playerCardInner}>
                <View style={styles.playerHeader}>
                  <Text style={styles.playerLabel}>PLAYER {idx + 1}</Text>
                  {players.length > 1 && (
                    <TouchableOpacity
                      onPress={() => removePlayer(player.id)}
                      hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
                    >
                      <Text style={styles.removeBtn}>×</Text>
                    </TouchableOpacity>
                  )}
                </View>

                <TextInput
                  ref={el => { nameRefs.current[idx] = el; }}
                  style={styles.nameInput}
                  placeholder="Name"
                  placeholderTextColor="#444"
                  value={player.name}
                  onChangeText={val => updateName(player.id, val)}
                  autoCapitalize="words"
                  returnKeyType="done"
                  maxLength={20}
                />

                {hasTaxMan && (
                  <View style={styles.taxManRow}>
                    <Text style={styles.taxManLabel}>Tax Man:</Text>
                    <TextInput
                      style={styles.taxManInput}
                      value={player.taxMan > 0 ? String(player.taxMan) : ''}
                      onChangeText={val => updateTaxMan(player.id, val)}
                      keyboardType="number-pad"
                      placeholderTextColor="#39FF14"
                      placeholder="90"
                      maxLength={3}
                      selectTextOnFocus
                    />
                    <Text style={styles.taxManHint}>shoot below to win</Text>
                  </View>
                )}

                {/* Handicap input - only show when Nassau with handicaps enabled */}
                {activeGames.has('nassau') && nassauHandicaps && (
                  <View style={styles.handicapRow}>
                    <Text style={styles.handicapLabel}>Handicap:</Text>
                    <TextInput
                      style={styles.handicapInput}
                      value={player.handicap !== undefined ? String(player.handicap) : ''}
                      onChangeText={val => updateHandicap(player.id, val)}
                      keyboardType="number-pad"
                      placeholderTextColor="#555"
                      placeholder="0"
                      maxLength={2}
                      selectTextOnFocus
                    />
                    <Text style={styles.handicapHint}>(0-36)</Text>
                  </View>
                )}
              </View>
            </BevelCard>
          ))}
        </View>

        {/* Team Assignment (Vegas + Best Ball) */}
        {(activeGames.has('vegas') || activeGames.has('best-ball')) && players.filter(p => p.name.trim()).length >= 2 && (
          <BevelCard style={styles.configPanel}>
            <View style={styles.cardHighlight} />
            <Text style={styles.teamSectionLabel}>TEAMS</Text>
            {players.filter(p => p.name.trim()).map((player) => {
              const team = teamAssignment[player.id] ?? 'A';
              return (
                <View key={player.id} style={styles.teamRow}>
                  <Text style={styles.teamPlayerName}>{player.name}</Text>
                  <View style={styles.nassauToggleGroup}>
                    <TouchableOpacity
                      style={[styles.pillBtn, team === 'A' && styles.pillBtnActive]}
                      onPress={() => setTeamAssignment(prev => ({ ...prev, [player.id]: 'A' }))}
                      activeOpacity={0.7}
                    >
                      <Text style={[styles.pillBtnText, team === 'A' && styles.pillBtnTextActive]}>Team A</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={[styles.pillBtn, team === 'B' && styles.pillBtnActive]}
                      onPress={() => setTeamAssignment(prev => ({ ...prev, [player.id]: 'B' }))}
                      activeOpacity={0.7}
                    >
                      <Text style={[styles.pillBtnText, team === 'B' && styles.pillBtnTextActive]}>Team B</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              );
            })}
          </BevelCard>
        )}

        {/* Bottom buttons */}
        <View style={styles.bottomBtns}>
          {players.length < MAX_PLAYERS ? (
            <TouchableOpacity style={styles.secondaryBtnOuter} onPress={addPlayer} activeOpacity={0.7}>
              <LinearGradient
                colors={['#1e1e1e', '#141414']}
                style={styles.secondaryBtnInner}
              >
                <View style={styles.secondaryBtnHighlight} />
                <View
                  style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
                />
                <Text style={styles.secondaryBtnText}>+ Add Player</Text>
              </LinearGradient>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity style={styles.secondaryBtnOuter} onPress={() => setStep(1)} activeOpacity={0.7}>
              <LinearGradient
                colors={['#1e1e1e', '#141414']}
                style={styles.secondaryBtnInner}
              >
                <View style={styles.secondaryBtnHighlight} />
                <View
                  style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
                />
                <Text style={styles.secondaryBtnText}>← Back</Text>
              </LinearGradient>
            </TouchableOpacity>
          )}
          <TouchableOpacity style={styles.primaryBtnOuter} onPress={handleStart} activeOpacity={0.85}>
            <LinearGradient
              colors={['#52ff20', '#2dcc08', '#1fa005']}
              locations={[0, 0.6, 1]}
              start={{ x: 0.5, y: 0 }}
              end={{ x: 0.5, y: 1 }}
              style={styles.primaryBtnGrad}
            >
              <View style={styles.btnSpecular} />
              <View style={styles.btnEdgeTop} />
              <View style={styles.btnEdgeBottom} />
              <View
                style={[StyleSheet.absoluteFill, { borderRadius: 14, overflow: 'hidden' }]}
              />
              <Text style={styles.primaryBtnText}>Start Round →</Text>
            </LinearGradient>
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* Custom Alert Modal */}
      {alertMsg && (
        <Modal
          transparent
          animationType="fade"
          visible={!!alertMsg}
          onRequestClose={() => setAlertMsg(null)}
        >
          <View style={styles.alertOverlay}>
            <View style={styles.alertBox}>
              <View style={styles.alertHighlight} />
              <Text style={styles.alertTitle}>{alertMsg.title}</Text>
              <Text style={styles.alertBody}>{alertMsg.body}</Text>
              <TouchableOpacity
                style={styles.alertBtn}
                onPress={() => setAlertMsg(null)}
                activeOpacity={0.8}
              >
                <LinearGradient
                  colors={['#44ff18', '#28cc08']}
                  start={{ x: 0.5, y: 0 }}
                  end={{ x: 0.5, y: 1 }}
                  style={styles.alertBtnGrad}
                >
                  <View
                    style={[StyleSheet.absoluteFill, { borderRadius: 12, overflow: 'hidden' }]}
                  />
                  <Text style={styles.alertBtnText}>Got it</Text>
                </LinearGradient>
              </TouchableOpacity>
            </View>
          </View>
        </Modal>
      )}
      </KeyboardAvoidingView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  bgFull: { flex: 1, width: '100%' },
  bgOverlay: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(0,0,0,0.58)' },
  flex: { flex: 1, width: '100%' },
  scroll: { flex: 1, width: '100%' },
  content: { padding: 20, paddingBottom: 200, width: '100%' },

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
  },

  // Step indicator
  stepIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 24,
  },
  stepDot: {
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  stepDotActive: {
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.6,
    shadowRadius: 8,
    elevation: 6,
  },
  stepDotHighlight: {
    position: 'absolute',
    top: 2,
    left: 4,
    right: 4,
    height: 6,
    borderRadius: 3,
    backgroundColor: 'rgba(255,255,255,0.3)',
  },
  stepDotComplete: {
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 6,
  },
  stepCheck: {
    color: '#000',
    fontWeight: '800',
    fontSize: 14,
  },
  stepLine: {
    width: 60,
    height: 2,
    backgroundColor: '#242424',
  },
  stepLineComplete: {
    backgroundColor: '#39FF14',
  },

  section: { marginBottom: 20 },
  sectionTitle: { fontSize: 22, fontWeight: '700', color: '#fff', marginBottom: 4 },
  sectionSubtitle: { fontSize: 13, color: '#888', marginBottom: 14 },

  // Icon grid
  iconGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 16,
    justifyContent: 'flex-start',
    marginTop: 16,
  },
  gameIconWrapper: {
    width: '30%',
    alignItems: 'center',
    marginBottom: 12,
  },
  gameIconOuter: {
    width: 96,
    height: 96,
    borderRadius: 22,
  },
  gameIconOuterActive: {
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.85,
    shadowRadius: 24,
    elevation: 18,
  },
  gameIconOuterInactive: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.7,
    shadowRadius: 12,
    elevation: 8,
  },
  gameIconGrad: {
    width: 96,
    height: 96,
    borderRadius: 22,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
  },
  iconSpecularPrimary: {
    position: 'absolute',
    top: 0,
    left: '8%',
    right: '8%',
    height: '52%',
    borderTopLeftRadius: 22,
    borderTopRightRadius: 22,
    borderBottomLeftRadius: 48,
    borderBottomRightRadius: 48,
  },
  iconSpecularDot: {
    position: 'absolute',
    top: 9,
    left: '28%',
    width: '28%',
    height: 9,
    borderRadius: 5,
    backgroundColor: 'rgba(255,255,255,0.70)',
  },
  iconBottomShadow: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: '38%',
    borderBottomLeftRadius: 22,
    borderBottomRightRadius: 22,
  },
  iconTopEdge: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1.5,
    backgroundColor: 'rgba(255,255,255,0.50)',
    borderTopLeftRadius: 22,
    borderTopRightRadius: 22,
  },
  gameIconEmoji: {
    fontSize: 38,
    textShadowColor: 'rgba(0,0,0,0.55)',
    textShadowOffset: { width: 0, height: 3 },
    textShadowRadius: 6,
    zIndex: 4,
  },
  gameIconCheck: {
    position: 'absolute',
    bottom: 4,
    right: 4,
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: 'rgba(255,255,255,0.9)',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 3,
  },
  gameIconCheckText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#000',
    lineHeight: 13,
  },
  gameIconLabel: {
    marginTop: 6,
    fontSize: 11,
    color: '#555',
    fontWeight: '600',
    letterSpacing: 0.3,
    textAlign: 'center',
  },
  gameIconLabelActive: {
    color: '#fff',
  },

  // Config panel
  configPanel: {
    marginTop: 20,
    padding: 22,
  },
  cardHighlight: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.06)',
  },
  configRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 16,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#1e1e1e',
  },
  configLabel: {
    color: '#bbb',
    fontSize: 17,
    fontWeight: '600',
  },
  configRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  configAmountInput: {
    backgroundColor: '#080808',
    borderWidth: 1,
    borderColor: '#2a2a2a',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 18,
    fontWeight: '700',
    color: '#39FF14',
    width: 84,
    textAlign: 'center',
  },
  nassauOpts: {
    marginTop: 12,
    paddingBottom: 16,
  },

  // Player cards (Step 1)
  playerCard: {
    marginBottom: 16,
  },
  playerCardInner: {
    padding: 16,
  },
  playerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  playerLabel: { 
    fontSize: 11, 
    fontWeight: '600', 
    color: '#555', 
    textTransform: 'uppercase', 
    letterSpacing: 1.5 
  },
  removeBtn: { fontSize: 18, color: '#555', fontWeight: '400' },

  // Recessed input (inset look)
  nameInput: {
    backgroundColor: '#060606',
    borderRadius: 10,
    borderTopWidth: 1,
    borderTopColor: 'rgba(0,0,0,0.95)',       // dark top = shadow inside hole
    borderLeftWidth: 1,
    borderLeftColor: 'rgba(0,0,0,0.6)',
    borderRightWidth: 1,
    borderRightColor: 'rgba(255,255,255,0.03)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.06)', // light bounce at bottom
    paddingHorizontal: 14,
    paddingVertical: 14,
    fontSize: 17,
    color: '#fff',
    marginBottom: 10,
  },

  taxManRow: { flexDirection: 'row', alignItems: 'center' },
  taxManLabel: { fontSize: 15, color: '#fff', marginRight: 10 },
  // Glowing inset input
  taxManInput: {
    backgroundColor: '#040a02',
    borderRadius: 10,
    borderWidth: 2,
    borderColor: '#39FF14',
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.6,
    shadowRadius: 10,
    elevation: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 22,
    fontWeight: '800',
    color: '#39FF14',
    width: 72,
    textAlign: 'center',
    marginRight: 10,
  },
  taxManHint: { fontSize: 12, color: '#555', flex: 1 },

  // Handicap row
  handicapRow: { flexDirection: 'row', alignItems: 'center', marginTop: 10 },
  handicapLabel: { fontSize: 15, color: '#888', marginRight: 10 },
  handicapInput: {
    backgroundColor: '#060606',
    borderRadius: 10,
    borderTopWidth: 1,
    borderTopColor: 'rgba(0,0,0,0.95)',
    borderLeftWidth: 1,
    borderLeftColor: 'rgba(0,0,0,0.6)',
    borderRightWidth: 1,
    borderRightColor: 'rgba(255,255,255,0.03)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.06)',
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 20,
    fontWeight: '700',
    color: '#ccc',
    width: 60,
    textAlign: 'center',
    marginRight: 10,
  },
  handicapHint: { fontSize: 12, color: '#555', flex: 1 },

  // Bottom buttons
  bottomBtns: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 24,
  },
  primaryBtnOuter: {
    flex: 1,
    borderRadius: 14,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.55,
    shadowRadius: 20,
    elevation: 14,
  },
  primaryBtnDisabled: {
    shadowOpacity: 0,
  },
  primaryBtnGrad: {
    borderRadius: 14,
    paddingVertical: 18,
    alignItems: 'center',
    overflow: 'hidden',
    position: 'relative',
  },
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
  primaryBtnText: { color: '#000', fontWeight: '900', fontSize: 18, letterSpacing: 0.3, zIndex: 1 },
  
  secondaryBtnOuter: {
    flex: 1,
    borderRadius: 14,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.5,
    shadowRadius: 6,
    elevation: 4,
  },
  secondaryBtnInner: {
    borderRadius: 14,
    paddingVertical: 18,
    alignItems: 'center',
    borderWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.08)',
    borderColor: '#2a2a2a',
    overflow: 'hidden',
  },
  secondaryBtnHighlight: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.06)',
  },
  secondaryBtnText: { fontSize: 16, color: '#888' },

  dollarSign: {
    color: '#666',
    fontSize: 17,
    marginRight: 6,
  },

  // Nassau mode toggles (pill buttons)
  nassauModeRow: {
    flexDirection: 'row',
    marginTop: 16,
    gap: 10,
    paddingHorizontal: 16,
  },
  pillBtn: {
    flex: 1,
    paddingVertical: 13,
    paddingHorizontal: 16,
    borderRadius: 22,
    backgroundColor: '#1e1e1e',
    borderWidth: 1,
    borderColor: '#2a2a2a',
    alignItems: 'center',
    overflow: 'hidden',
  },
  pillBtnActive: {
    backgroundColor: '#39FF14',
    borderColor: '#39FF14',
  },
  pillBtnText: {
    fontSize: 15,
    fontWeight: '600',
    color: '#888',
  },
  pillBtnTextActive: {
    color: '#000',
  },

  // Nassau option rows (Press, Handicaps)
  nassauOptionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 14,
    paddingTop: 14,
    paddingHorizontal: 16,
    borderTopWidth: 1,
    borderTopColor: '#242424',
  },
  nassauOptionLabel: {
    fontSize: 16,
    color: '#aaa',
    fontWeight: '600',
  },
  nassauToggleGroup: {
    flexDirection: 'row',
    gap: 10,
  },

  // Vegas team assignment
  teamSectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#555',
    letterSpacing: 1.5,
    textTransform: 'uppercase',
    marginBottom: 14,
  },
  teamRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#1a1a1a',
  },
  teamPlayerName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#ddd',
    flex: 1,
  },

  validationHint: {
    color: '#ff4444',
    fontSize: 14,
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 8,
  },

  // Custom Alert Modal
  alertOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.75)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
  },
  alertBox: {
    backgroundColor: '#161616',
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#2a2a2a',
    padding: 24,
    width: '100%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.8,
    shadowRadius: 24,
    elevation: 20,
    overflow: 'hidden',
    position: 'relative',
  },
  alertHighlight: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  alertTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#fff',
    marginBottom: 10,
    textAlign: 'center',
  },
  alertBody: {
    fontSize: 15,
    color: '#888',
    textAlign: 'center',
    marginBottom: 24,
    lineHeight: 22,
  },
  alertBtn: {
    borderRadius: 12,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  alertBtnGrad: {
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  alertBtnText: {
    color: '#000',
    fontWeight: '800',
    fontSize: 16,
  },

  // Saved Players Quick-Add
  savedPlayersSection: {
    marginBottom: 16,
  },
  savedPlayersLabel: {
    color: '#666',
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 8,
    letterSpacing: 1,
  },
  savedPlayerChip: {
    backgroundColor: '#1a1a1a',
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
    marginRight: 8,
    borderWidth: 1,
    borderColor: '#333',
  },
  savedPlayerName: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  savedPlayerTM: {
    color: '#555',
    fontSize: 11,
  },
});
