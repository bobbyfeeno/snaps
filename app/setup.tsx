import { useRouter } from 'expo-router';
import { useRef, useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { GameConfig, GameMode, GameSetup, Player } from '../types';

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
];

export default function SetupScreen() {
  const router = useRouter();
  const [step, setStep] = useState<1 | 2>(1);
  const [players, setPlayers] = useState<Player[]>([createPlayer(), createPlayer()]);
  const nameRefs = useRef<(TextInput | null)[]>([]);
  
  // Game selection state
  const [activeGames, setActiveGames] = useState<Set<GameMode>>(new Set(['taxman']));
  const [gameAmounts, setGameAmounts] = useState<Record<GameMode, string>>({
    taxman: '10',
    nassau: '5',
    skins: '5',
    wolf: '2',
    'bingo-bango-bongo': '1',
    snake: '10',
  });

  // ─── Step 1: Player Management ────────────────────────────────────────────

  function addPlayer() {
    if (players.length < MAX_PLAYERS) {
      setPlayers(prev => [...prev, createPlayer()]);
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

  function handleNextStep() {
    for (const p of players) {
      if (!p.name.trim()) {
        Alert.alert('Missing Name', 'Every player needs a name.');
        return;
      }
      if (p.taxMan <= 0 || p.taxMan > 200) {
        Alert.alert('Invalid Tax Man', `"${p.name || 'A player'}" needs a valid Tax Man score (1–200).`);
        return;
      }
    }
    setStep(2);
  }

  // ─── Step 2: Game Selection ───────────────────────────────────────────────

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
    // Validation
    if (activeGames.size === 0) {
      Alert.alert('No Games Selected', 'Select at least one game to play.');
      return;
    }

    // Check Wolf player requirement
    if (activeGames.has('wolf') && players.length < 3) {
      Alert.alert('Not Enough Players', 'Wolf requires at least 3 players.');
      return;
    }

    // Validate all active game amounts
    for (const mode of activeGames) {
      const amount = parseFloat(gameAmounts[mode]);
      if (isNaN(amount) || amount <= 0) {
        const gameName = GAME_DEFS.find(g => g.mode === mode)?.name ?? mode;
        Alert.alert('Invalid Amount', `Enter a valid dollar amount for ${gameName}.`);
        return;
      }
    }

    // Build GameConfig array
    const games: GameConfig[] = [];
    for (const mode of activeGames) {
      const amount = parseFloat(gameAmounts[mode]);
      switch (mode) {
        case 'taxman':
          games.push({ mode: 'taxman', config: { taxAmount: amount } });
          break;
        case 'nassau':
          games.push({ mode: 'nassau', config: { betAmount: amount } });
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
      }
    }

    gameSetup = { players, games };
    router.push('/scores');
  }

  // ─── Render Step 1: Players ───────────────────────────────────────────────

  if (step === 1) {
    return (
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          style={styles.scroll}
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
        >
          {/* Step indicator */}
          <View style={styles.stepIndicator}>
            <View style={[styles.stepDot, styles.stepDotActive]} />
            <View style={styles.stepLine} />
            <View style={styles.stepDot} />
          </View>

          {/* Players */}
          <View style={styles.section}>
            <Text style={styles.sectionLabel}>Players</Text>
            <Text style={styles.sectionHint}>Name + their Tax Man score</Text>

            {players.map((player, idx) => (
              <View key={player.id} style={styles.playerCard}>
                <View style={styles.playerHeader}>
                  <Text style={styles.playerNum}>Player {idx + 1}</Text>
                  {players.length > 1 && (
                    <TouchableOpacity
                      onPress={() => removePlayer(player.id)}
                      hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
                    >
                      <Text style={styles.removeBtn}>✕</Text>
                    </TouchableOpacity>
                  )}
                </View>

                <TextInput
                  ref={el => { nameRefs.current[idx] = el; }}
                  style={styles.nameInput}
                  placeholder="Name"
                  placeholderTextColor="#5a8a5a"
                  value={player.name}
                  onChangeText={val => updateName(player.id, val)}
                  autoCapitalize="words"
                  returnKeyType="done"
                  maxLength={20}
                />

                <View style={styles.taxManRow}>
                  <Text style={styles.taxManLabel}>Tax Man:</Text>
                  <TextInput
                    style={styles.taxManInput}
                    value={player.taxMan > 0 ? String(player.taxMan) : ''}
                    onChangeText={val => updateTaxMan(player.id, val)}
                    keyboardType="number-pad"
                    placeholderTextColor="#5a8a5a"
                    placeholder="90"
                    maxLength={3}
                    selectTextOnFocus
                  />
                  <Text style={styles.taxManHint}>shoot below to win</Text>
                </View>
              </View>
            ))}

            {players.length < MAX_PLAYERS && (
              <TouchableOpacity style={styles.addPlayerBtn} onPress={addPlayer} activeOpacity={0.7}>
                <Text style={styles.addPlayerText}>+ Add Player</Text>
              </TouchableOpacity>
            )}
          </View>

          <TouchableOpacity style={styles.nextBtn} onPress={handleNextStep} activeOpacity={0.8}>
            <Text style={styles.nextBtnText}>Next →</Text>
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
    );
  }

  // ─── Render Step 2: Games ─────────────────────────────────────────────────

  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        {/* Step indicator */}
        <View style={styles.stepIndicator}>
          <TouchableOpacity onPress={() => setStep(1)}>
            <View style={[styles.stepDot, styles.stepDotComplete]}>
              <Text style={styles.stepCheck}>✓</Text>
            </View>
          </TouchableOpacity>
          <View style={[styles.stepLine, styles.stepLineComplete]} />
          <View style={[styles.stepDot, styles.stepDotActive]} />
        </View>

        {/* Header */}
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>Choose Your Games</Text>
          <Text style={styles.sectionHint}>Stack multiple games — they all run at once</Text>
        </View>

        {/* Game cards */}
        {GAME_DEFS.map(game => {
          const isActive = activeGames.has(game.mode);
          const isDisabled = game.minPlayers !== undefined && players.length < game.minPlayers;
          
          return (
            <View 
              key={game.mode} 
              style={[
                styles.gameCard,
                isActive && styles.gameCardActive,
                isDisabled && styles.gameCardDisabled,
              ]}
            >
              <View style={styles.gameHeader}>
                <TouchableOpacity
                  onPress={() => !isDisabled && toggleGame(game.mode)}
                  style={[
                    styles.toggle,
                    isActive && styles.toggleActive,
                    isDisabled && styles.toggleDisabled,
                  ]}
                  activeOpacity={0.7}
                  disabled={Boolean(isDisabled)}
                >
                  {isActive && <Text style={styles.toggleCheck}>✓</Text>}
                </TouchableOpacity>
                <View style={styles.gameInfo}>
                  <Text style={[styles.gameName, isDisabled && styles.gameNameDisabled]}>
                    {game.name}
                  </Text>
                  <Text style={[styles.gameDesc, isDisabled && styles.gameDescDisabled]}>
                    {game.description}
                    {isDisabled && ` (needs ${game.minPlayers}+ players)`}
                  </Text>
                </View>
              </View>
              
              {isActive && (
                <View style={styles.gameAmountRow}>
                  <Text style={styles.gameAmountLabel}>{game.inputLabel}</Text>
                  <View style={styles.gameAmountInput}>
                    <Text style={styles.dollarSign}>$</Text>
                    <TextInput
                      style={styles.amountInput}
                      value={gameAmounts[game.mode]}
                      onChangeText={val => updateGameAmount(game.mode, val)}
                      keyboardType="decimal-pad"
                      placeholderTextColor="#5a8a5a"
                      maxLength={6}
                      selectTextOnFocus
                    />
                  </View>
                </View>
              )}
            </View>
          );
        })}

        {/* Validation message */}
        {activeGames.size === 0 && (
          <Text style={styles.validationHint}>Select at least one game</Text>
        )}

        <TouchableOpacity 
          style={[styles.startBtn, activeGames.size === 0 && styles.startBtnDisabled]} 
          onPress={handleStart} 
          activeOpacity={0.8}
          disabled={Boolean(activeGames.size === 0)}
        >
          <Text style={styles.startBtnText}>Start Round →</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.backBtn} onPress={() => setStep(1)} activeOpacity={0.7}>
          <Text style={styles.backBtnText}>← Back to Players</Text>
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: '#0d1f0d' },
  scroll: { flex: 1 },
  content: { padding: 20, paddingBottom: 48 },

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
    backgroundColor: '#162416',
    borderWidth: 2,
    borderColor: '#2a4a2a',
    justifyContent: 'center',
    alignItems: 'center',
  },
  stepDotActive: {
    borderColor: '#39FF14',
    backgroundColor: '#0d2a0d',
  },
  stepDotComplete: {
    backgroundColor: '#39FF14',
    borderColor: '#39FF14',
  },
  stepCheck: {
    color: '#000',
    fontWeight: '800',
    fontSize: 14,
  },
  stepLine: {
    width: 60,
    height: 2,
    backgroundColor: '#2a4a2a',
  },
  stepLineComplete: {
    backgroundColor: '#39FF14',
  },

  section: { marginBottom: 20 },
  sectionLabel: { fontSize: 20, fontWeight: '700', color: '#39FF14', marginBottom: 4 },
  sectionHint: { fontSize: 13, color: '#5a8a5a', marginBottom: 14 },

  // Player cards (Step 1)
  playerCard: {
    backgroundColor: '#162416',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    padding: 16,
    marginBottom: 12,
  },
  playerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  playerNum: { fontSize: 13, fontWeight: '600', color: '#5a8a5a', textTransform: 'uppercase', letterSpacing: 1 },
  removeBtn: { fontSize: 16, color: '#ff5555', fontWeight: '700' },

  nameInput: {
    backgroundColor: '#0d1f0d',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    paddingHorizontal: 14,
    paddingVertical: 14,
    fontSize: 18,
    color: '#fff',
    marginBottom: 10,
  },

  taxManRow: { flexDirection: 'row', alignItems: 'center' },
  taxManLabel: { fontSize: 15, color: '#88bb88', marginRight: 10 },
  taxManInput: {
    backgroundColor: '#0d1f0d',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#39FF14',
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 22,
    fontWeight: '700',
    color: '#39FF14',
    width: 72,
    textAlign: 'center',
    marginRight: 10,
  },
  taxManHint: { fontSize: 12, color: '#5a8a5a', flex: 1 },

  addPlayerBtn: {
    borderWidth: 2,
    borderColor: '#2a4a2a',
    borderStyle: 'dashed',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 4,
  },
  addPlayerText: { fontSize: 17, color: '#39FF14', fontWeight: '600' },

  nextBtn: {
    backgroundColor: '#39FF14',
    borderRadius: 16,
    paddingVertical: 20,
    alignItems: 'center',
    marginTop: 8,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  nextBtnText: { fontSize: 20, fontWeight: '800', color: '#000' },

  // Game cards (Step 2)
  gameCard: {
    backgroundColor: '#162416',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    padding: 16,
    marginBottom: 12,
  },
  gameCardActive: {
    borderColor: '#39FF14',
    backgroundColor: '#0f2a0f',
  },
  gameCardDisabled: {
    opacity: 0.5,
  },

  gameHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },

  toggle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#0d1f0d',
    borderWidth: 2,
    borderColor: '#2a4a2a',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
    marginTop: 2,
  },
  toggleActive: {
    backgroundColor: '#39FF14',
    borderColor: '#39FF14',
  },
  toggleDisabled: {
    borderColor: '#1a2a1a',
  },
  toggleCheck: {
    color: '#000',
    fontWeight: '800',
    fontSize: 16,
  },

  gameInfo: {
    flex: 1,
  },
  gameName: {
    fontSize: 17,
    fontWeight: '700',
    color: '#fff',
    marginBottom: 4,
  },
  gameNameDisabled: {
    color: '#666',
  },
  gameDesc: {
    fontSize: 13,
    color: '#88bb88',
    lineHeight: 18,
  },
  gameDescDisabled: {
    color: '#555',
  },

  gameAmountRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 14,
    paddingTop: 14,
    borderTopWidth: 1,
    borderTopColor: '#2a4a2a',
  },
  gameAmountLabel: {
    fontSize: 14,
    color: '#5a8a5a',
  },
  gameAmountInput: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#0d1f0d',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#39FF14',
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  dollarSign: {
    fontSize: 18,
    color: '#39FF14',
    marginRight: 4,
  },
  amountInput: {
    fontSize: 20,
    fontWeight: '700',
    color: '#fff',
    width: 60,
    textAlign: 'center',
  },

  validationHint: {
    color: '#ff5555',
    fontSize: 14,
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 8,
  },

  startBtn: {
    backgroundColor: '#39FF14',
    borderRadius: 16,
    paddingVertical: 20,
    alignItems: 'center',
    marginTop: 16,
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
  startBtnDisabled: {
    backgroundColor: '#1a3a1a',
    shadowOpacity: 0,
  },
  startBtnText: { fontSize: 20, fontWeight: '800', color: '#000' },

  backBtn: {
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 8,
  },
  backBtnText: { fontSize: 16, color: '#5a8a5a' },
});
