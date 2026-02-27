import AsyncStorage from '@react-native-async-storage/async-storage';
import { RoundRecord, SavedPlayer } from '../types';

const ROUNDS_KEY = '@snaps/rounds';
const SAVED_PLAYERS_KEY = '@snaps/saved_players';

function generateId(): string {
  return Math.random().toString(36).slice(2, 9);
}

// ─── Rounds ─────────────────────────────────────────────────────────────────

export async function getRounds(): Promise<RoundRecord[]> {
  try {
    const json = await AsyncStorage.getItem(ROUNDS_KEY);
    if (!json) return [];
    return JSON.parse(json) as RoundRecord[];
  } catch {
    return [];
  }
}

export async function saveRound(round: RoundRecord): Promise<void> {
  try {
    const existing = await getRounds();
    const updated = [round, ...existing]; // prepend (newest first)
    await AsyncStorage.setItem(ROUNDS_KEY, JSON.stringify(updated));
  } catch {
    // silently fail
  }
}

export async function deleteRound(id: string): Promise<void> {
  try {
    const existing = await getRounds();
    const updated = existing.filter(r => r.id !== id);
    await AsyncStorage.setItem(ROUNDS_KEY, JSON.stringify(updated));
  } catch {
    // silently fail
  }
}

// ─── Saved Players ──────────────────────────────────────────────────────────

export async function getSavedPlayers(): Promise<SavedPlayer[]> {
  try {
    const json = await AsyncStorage.getItem(SAVED_PLAYERS_KEY);
    if (!json) return [];
    return JSON.parse(json) as SavedPlayer[];
  } catch {
    return [];
  }
}

export async function savePlayer(player: Omit<SavedPlayer, 'id'>): Promise<SavedPlayer> {
  const newPlayer: SavedPlayer = {
    ...player,
    id: generateId(),
  };
  try {
    const existing = await getSavedPlayers();
    const updated = [...existing, newPlayer];
    await AsyncStorage.setItem(SAVED_PLAYERS_KEY, JSON.stringify(updated));
  } catch {
    // silently fail
  }
  return newPlayer;
}

export async function updatePlayer(player: SavedPlayer): Promise<void> {
  try {
    const existing = await getSavedPlayers();
    const updated = existing.map(p => (p.id === player.id ? player : p));
    await AsyncStorage.setItem(SAVED_PLAYERS_KEY, JSON.stringify(updated));
  } catch {
    // silently fail
  }
}

export async function deletePlayer(id: string): Promise<void> {
  try {
    const existing = await getSavedPlayers();
    const updated = existing.filter(p => p.id !== id);
    await AsyncStorage.setItem(SAVED_PLAYERS_KEY, JSON.stringify(updated));
  } catch {
    // silently fail
  }
}

// ─── Stats Helpers ──────────────────────────────────────────────────────────

export function computePlayerAverages(rounds: RoundRecord[]): Array<{ name: string; avg: number; roundsPlayed: number }> {
  const totals: Record<string, { sum: number; count: number }> = {};
  for (const round of rounds) {
    for (const player of round.players) {
      const playerScores = round.scores[player.id];
      if (!playerScores) continue;
      const total = playerScores.reduce((s, v) => s + (v ?? 0), 0);
      if (total === 0) continue; // skip if no scores entered
      if (!totals[player.name]) totals[player.name] = { sum: 0, count: 0 };
      totals[player.name].sum += total;
      totals[player.name].count += 1;
    }
  }
  return Object.entries(totals)
    .map(([name, { sum, count }]) => ({ name, avg: Math.round(sum / count), roundsPlayed: count }))
    .sort((a, b) => a.avg - b.avg); // best (lowest) first
}
