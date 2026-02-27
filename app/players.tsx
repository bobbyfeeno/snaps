import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  ImageBackground,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { deletePlayer, getSavedPlayers, savePlayer, updatePlayer } from '../lib/storage';
import { SavedPlayer } from '../types';

export default function PlayersScreen() {
  const router = useRouter();
  const [players, setPlayers] = useState<SavedPlayer[]>([]);
  const [loading, setLoading] = useState(true);

  // Add/Edit form state
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formName, setFormName] = useState('');
  const [formTaxMan, setFormTaxMan] = useState('90');
  const [formHandicap, setFormHandicap] = useState('');

  const loadPlayers = () => {
    getSavedPlayers()
      .then(setPlayers)
      .catch(() => setPlayers([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadPlayers();
  }, []);

  const openAddForm = () => {
    setEditingId(null);
    setFormName('');
    setFormTaxMan('90');
    setFormHandicap('');
    setShowForm(true);
  };

  const openEditForm = (player: SavedPlayer) => {
    setEditingId(player.id);
    setFormName(player.name);
    setFormTaxMan(String(player.taxMan));
    setFormHandicap(player.handicap !== undefined ? String(player.handicap) : '');
    setShowForm(true);
  };

  const cancelForm = () => {
    setShowForm(false);
    setEditingId(null);
  };

  const handleSave = async () => {
    const name = formName.trim();
    if (!name) return;

    const taxMan = parseInt(formTaxMan, 10) || 90;
    const handicapVal = parseInt(formHandicap, 10);
    const handicap = isNaN(handicapVal) ? undefined : Math.min(36, Math.max(0, handicapVal));

    try {
      if (editingId) {
        await updatePlayer({ id: editingId, name, taxMan, handicap });
      } else {
        await savePlayer({ name, taxMan, handicap });
      }
      loadPlayers();
      cancelForm();
    } catch {
      // silently fail
    }
  };

  const handleDelete = (id: string) => {
    deletePlayer(id)
      .then(() => loadPlayers())
      .catch(() => {});
  };

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
            <Text style={styles.backBtn}>← Players</Text>
          </TouchableOpacity>
        </View>

        {/* Add Player Button */}
        {!showForm && (
          <TouchableOpacity
            style={styles.addBtn}
            onPress={openAddForm}
            activeOpacity={0.8}
          >
            <Text style={styles.addBtnText}>+ Add Player</Text>
          </TouchableOpacity>
        )}

        <ScrollView
          style={styles.scroll}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Add/Edit Form */}
          {showForm && (
            <View style={styles.formCard}>
              <Text style={styles.formTitle}>
                {editingId ? 'Edit Player' : 'New Player'}
              </Text>
              <TextInput
                style={styles.input}
                placeholder="Name"
                placeholderTextColor="#444"
                value={formName}
                onChangeText={setFormName}
                autoCapitalize="words"
                maxLength={20}
                autoFocus
              />
              <View style={styles.formRow}>
                <View style={styles.formField}>
                  <Text style={styles.formLabel}>Tax Man</Text>
                  <TextInput
                    style={styles.smallInput}
                    placeholder="90"
                    placeholderTextColor="#444"
                    value={formTaxMan}
                    onChangeText={setFormTaxMan}
                    keyboardType="number-pad"
                    maxLength={3}
                  />
                </View>
                <View style={styles.formField}>
                  <Text style={styles.formLabel}>Handicap</Text>
                  <TextInput
                    style={styles.smallInput}
                    placeholder="0 (optional)"
                    placeholderTextColor="#444"
                    value={formHandicap}
                    onChangeText={setFormHandicap}
                    keyboardType="number-pad"
                    maxLength={2}
                  />
                </View>
              </View>
              <View style={styles.formBtns}>
                <TouchableOpacity
                  style={styles.cancelBtn}
                  onPress={cancelForm}
                  activeOpacity={0.7}
                >
                  <Text style={styles.cancelBtnText}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.saveBtn}
                  onPress={handleSave}
                  activeOpacity={0.8}
                >
                  <Text style={styles.saveBtnText}>Save</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}

          {/* Players List */}
          {loading ? (
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyText}>Loading...</Text>
            </View>
          ) : players.length === 0 && !showForm ? (
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyText}>
                No saved players yet.{'\n'}Add players to quickly fill your lineup.
              </Text>
            </View>
          ) : (
            players.map((player) => (
              <View key={player.id} style={styles.playerCard}>
                <View style={styles.playerInfo}>
                  <Text style={styles.playerName}>{player.name}</Text>
                  <Text style={styles.playerStats}>
                    TM: {player.taxMan}   HCP: {player.handicap ?? '—'}
                  </Text>
                </View>
                <View style={styles.playerActions}>
                  <TouchableOpacity
                    onPress={() => openEditForm(player)}
                    activeOpacity={0.6}
                    style={styles.actionBtn}
                  >
                    <Text style={styles.actionBtnText}>✏️</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={() => handleDelete(player.id)}
                    activeOpacity={0.6}
                    style={styles.actionBtn}
                  >
                    <Text style={styles.actionBtnText}>🗑</Text>
                  </TouchableOpacity>
                </View>
              </View>
            ))
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
  addBtn: {
    marginHorizontal: 16,
    marginBottom: 12,
    backgroundColor: '#39FF14',
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  addBtnText: {
    color: '#000',
    fontSize: 16,
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

  // Form styles
  formCard: {
    backgroundColor: '#161616',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#222',
    padding: 16,
    marginBottom: 16,
  },
  formTitle: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 12,
  },
  input: {
    backgroundColor: '#0a0a0a',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#2a2a2a',
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
    color: '#fff',
    marginBottom: 12,
  },
  formRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
  },
  formField: {
    flex: 1,
  },
  formLabel: {
    color: '#666',
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 6,
  },
  smallInput: {
    backgroundColor: '#0a0a0a',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#2a2a2a',
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    color: '#fff',
    textAlign: 'center',
  },
  formBtns: {
    flexDirection: 'row',
    gap: 12,
  },
  cancelBtn: {
    flex: 1,
    backgroundColor: '#1a1a1a',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#2a2a2a',
    paddingVertical: 12,
    alignItems: 'center',
  },
  cancelBtnText: {
    color: '#888',
    fontSize: 15,
    fontWeight: '600',
  },
  saveBtn: {
    flex: 1,
    backgroundColor: '#39FF14',
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: 'center',
  },
  saveBtnText: {
    color: '#000',
    fontSize: 15,
    fontWeight: '700',
  },

  // Player card styles
  playerCard: {
    backgroundColor: '#161616',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#222',
    padding: 16,
    marginBottom: 10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  playerInfo: {
    flex: 1,
  },
  playerName: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
  playerStats: {
    color: '#aaa',
    fontSize: 13,
    marginTop: 4,
  },
  playerActions: {
    flexDirection: 'row',
    gap: 12,
  },
  actionBtn: {
    padding: 4,
  },
  actionBtnText: {
    fontSize: 18,
  },
});
