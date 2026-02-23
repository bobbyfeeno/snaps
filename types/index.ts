export interface Player {
  id: string;
  name: string;
  taxMan: number; // Tax Man target score (used only when taxman game active)
}

// ─── Game Configs (per-game settings set at setup) ───────────────────────────

export interface TaxManConfig {
  taxAmount: number; // $ each loser pays per winner
}

export interface NassauConfig {
  betAmount: number; // $ per leg (front 9, back 9, full 18 = 3 possible payouts)
}

export interface SkinsConfig {
  betPerSkin: number; // $ value of each skin
}

export interface WolfConfig {
  betPerHole: number; // $ at stake per hole
}

export interface BingoBangoBongoConfig {
  betPerPoint: number; // $ per point differential at end
}

export interface SnakeConfig {
  snakeAmount: number; // $ the snake holder pays everyone at end
}

export type GameConfig =
  | { mode: 'taxman'; config: TaxManConfig }
  | { mode: 'nassau'; config: NassauConfig }
  | { mode: 'skins'; config: SkinsConfig }
  | { mode: 'wolf'; config: WolfConfig }
  | { mode: 'bingo-bango-bongo'; config: BingoBangoBongoConfig }
  | { mode: 'snake'; config: SnakeConfig };

export type GameMode = GameConfig['mode'];

// ─── Game Setup (what goes into a round) ────────────────────────────────────

export interface GameSetup {
  players: Player[];
  games: GameConfig[]; // at least 1 game must be selected
}

// ─── Per-hole tracking (stored in scores.tsx state) ─────────────────────────

// Wolf: which player is the Wolf, and who they picked as partner (null = Lone Wolf)
export interface WolfHoleState {
  wolfPlayerId: string;   // who is Wolf this hole (rotates by index)
  partnerId: string | null; // player Wolf picked; null = Lone Wolf
}

// Bingo Bango Bongo: 3 awards per hole (null = not yet awarded)
export interface BBBHoleState {
  bingoPlayerId: string | null; // first on green
  bangoPlayerId: string | null; // closest to pin
  bongoPlayerId: string | null; // first in hole
}

// Snake: who currently has the snake going into this hole
export interface SnakeHoleState {
  holderPlayerId: string | null; // null = nobody yet
  threeputters: string[];        // player IDs who 3-putted this hole
}

export interface HoleExtras {
  wolf?: WolfHoleState;
  bbb?: BBBHoleState;
  snake?: SnakeHoleState;
}

// ─── Results ────────────────────────────────────────────────────────────────

export interface Payout {
  from: string; // player name
  to: string;   // player name
  amount: number;
  game: GameMode; // which game this payout is from
}

export interface GameResult {
  mode: GameMode;
  label: string;       // "Tax Man", "Nassau", etc.
  payouts: Payout[];
  net: Record<string, number>; // net per player name for this game
}

export interface MultiGameResults {
  playerNames: string[];
  games: GameResult[];
  combinedNet: Record<string, number>; // sum across all games
}

// ─── Legacy support (for backwards compatibility during migration) ──────────

export interface PlayerResult {
  player: Player;
  score: number;
  beatTaxMan: boolean; // score < taxMan => winner
}
