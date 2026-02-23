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
import { GameSetup, Player } from '../types';

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

export default function SetupScreen() {
  const router = useRouter();
  const [players, setPlayers] = useState<Player[]>([createPlayer(), createPlayer()]);
  const [taxAmount, setTaxAmount] = useState('10');
  const nameRefs = useRef<(TextInput | null)[]>([]);

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

  function handleStart() {
    const tax = parseFloat(taxAmount);

    if (isNaN(tax) || tax <= 0) {
      Alert.alert('Invalid Tax Amount', 'Enter a dollar amount greater than $0.');
      return;
    }

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

    gameSetup = { players, taxAmount: tax };
    router.push('/scores');
  }

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
        {/* Tax Amount */}
        <View style={styles.section}>
          <Text style={styles.sectionLabel}>Tax Amount</Text>
          <Text style={styles.sectionHint}>$ each loser pays per winner</Text>
          <View style={styles.taxRow}>
            <Text style={styles.dollarSign}>$</Text>
            <TextInput
              style={styles.taxInput}
              value={taxAmount}
              onChangeText={setTaxAmount}
              keyboardType="decimal-pad"
              placeholderTextColor="#5a8a5a"
              maxLength={6}
              selectTextOnFocus
            />
          </View>
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

        <TouchableOpacity style={styles.startBtn} onPress={handleStart} activeOpacity={0.8}>
          <Text style={styles.startBtnText}>Enter Scores →</Text>
        </TouchableOpacity>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: '#0d1f0d' },
  scroll: { flex: 1 },
  content: { padding: 20, paddingBottom: 48 },

  section: { marginBottom: 28 },
  sectionLabel: { fontSize: 20, fontWeight: '700', color: '#39FF14', marginBottom: 4 },
  sectionHint: { fontSize: 13, color: '#5a8a5a', marginBottom: 14 },

  taxRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#162416',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#2a4a2a',
    paddingHorizontal: 16,
    height: 64,
  },
  dollarSign: { fontSize: 28, color: '#39FF14', marginRight: 6 },
  taxInput: {
    flex: 1,
    fontSize: 32,
    fontWeight: '700',
    color: '#fff',
  },

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

  startBtn: {
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
  startBtnText: { fontSize: 20, fontWeight: '800', color: '#000' },
});
