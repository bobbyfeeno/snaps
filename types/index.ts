export interface Player {
  id: string;
  name: string;
  taxMan: number; // Tax Man target score (used only when taxman game active)
  handicap?: number; // 0-36, optional, only used when Nassau useHandicaps=true
}

// ─── Game Configs (per-game settings set at setup) ───────────────────────────

export interface TaxManConfig {
  taxAmount: number; // $ each loser pays per winner
}

export interface NassauConfig {
  betAmount: number; // $ per leg (front 9, back 9, full 18 = 3 possible payouts)
  mode: 'stroke' | 'match'; // stroke = total score per leg, match = hole-by-hole wins
  press: 'none' | 'auto'; // 'auto' = auto-press when 2 down (match play only)
  useHandicaps: boolean; // apply handicap strokes per hole
  useHammer?: boolean;   // hammer doubling modifier
}

export interface VegasConfig {
  betPerPoint: number;  // $ per point difference
  flipBird: boolean;    // birdie team flips opponent's score high-first
  useHammer: boolean;   // hammer doubling modifier
  teamA: string[];      // player IDs on Team A
  teamB: string[];      // player IDs on Team B
}

export interface BestBallConfig {
  mode: 'stroke' | 'match'; // stroke = total best-ball over 18, match = hole-by-hole
  betAmount: number;         // stroke: $ per stroke diff | match: $ per hole won
  teamA: string[];
  teamB: string[];
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

export interface ScorecardConfig {} // no config needed

export interface StablefordConfig {
  betAmount: number; // $ per point difference
}

export interface RabbitConfig {
  rabbitAmount: number; // $ the rabbit holder pays everyone at end
}

export interface DotsConfig {
  betPerDot: number;  // $ per dot (paid by every other player)
  birdie: boolean;    // 1 under par = 1 dot (auto)
  eagle: boolean;     // 2+ under par = 2 dots (auto)
  sandy: boolean;     // par or better from bunker = 1 dot (manual)
  greenie: boolean;   // par 3, closest to pin making par or better = 1 dot (manual radio)
}

export interface SixesConfig {
  betPerSegment: number; // $ per segment (6 holes each, 3 segments)
}

// ─── Tier 2 Game Configs ────────────────────────────────────────────────────

export interface NinesConfig {
  betPerPoint: number; // $ per point difference at end (3-player game, 9 pts per hole)
}

export interface ScotchConfig {
  betPerPoint: number; // $ per point difference (5-pt Scotch: 2 low-ball + 3 low-total per hole)
  teamA: string[];     // player IDs on Team A (2 players)
  teamB: string[];     // player IDs on Team B (2 players)
}

export interface CtpConfig {
  betAmount: number; // $ winner collects from each other player on par 3s
}

export interface AcesDeucesConfig {
  betPerHole: number; // $ ace collects from deuce per hole
}

// ─── Tier 3 Game Configs ────────────────────────────────────────────────────

export interface QuotaConfig {
  betPerPoint: number;
  quotas: Record<string, number>; // playerId → target points
}

export interface TroubleConfig {
  betAmount: number;
  ob: boolean;        // Out of bounds
  water: boolean;     // Water hazard
  threePutt: boolean; // 3-putt
  sandTrap: boolean;  // Sand trap shot
  lostBall: boolean;  // Lost ball
}

export interface ArniesConfig {
  betAmount: number;
}

export interface BankerConfig {
  betAmount: number;
}

export interface MatchPlayConfig {
  betAmount: number;        // $ per match won (stroke play) or per hole (match play)
  mode: 'match' | 'stroke'; // match = hole-by-hole, stroke = total net strokes
  useHandicaps: boolean;    // apply USGA handicap strokes per hole
}

export interface TroubleHoleState {
  troubles: Record<string, string[]>; // playerId → array of trouble types
}

export interface ArniesHoleState {
  qualifiedPlayerIds: string[]; // players who got an Arnie this hole
}

export interface BankerHoleState {
  bankerId: string | null;
}

export type GameConfig =
  | { mode: 'taxman'; config: TaxManConfig }
  | { mode: 'nassau'; config: NassauConfig }
  | { mode: 'skins'; config: SkinsConfig }
  | { mode: 'wolf'; config: WolfConfig }
  | { mode: 'bingo-bango-bongo'; config: BingoBangoBongoConfig }
  | { mode: 'snake'; config: SnakeConfig }
  | { mode: 'scorecard'; config: ScorecardConfig }
  | { mode: 'vegas'; config: VegasConfig }
  | { mode: 'best-ball'; config: BestBallConfig }
  | { mode: 'stableford'; config: StablefordConfig }
  | { mode: 'rabbit'; config: RabbitConfig }
  | { mode: 'dots'; config: DotsConfig }
  | { mode: 'sixes'; config: SixesConfig }
  | { mode: 'nines'; config: NinesConfig }
  | { mode: 'scotch'; config: ScotchConfig }
  | { mode: 'ctp'; config: CtpConfig }
  | { mode: 'aces-deuces'; config: AcesDeucesConfig }
  | { mode: 'quota'; config: QuotaConfig }
  | { mode: 'trouble'; config: TroubleConfig }
  | { mode: 'arnies'; config: ArniesConfig }
  | { mode: 'banker'; config: BankerConfig }
  | { mode: 'match-play'; config: MatchPlayConfig };

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

// Dots/Junk: manual dot awards per hole
export interface DotsHoleState {
  sandyPlayerIds: string[];    // players who got a sandy (par or better from bunker)
  greeniePlayerId: string | null; // player who got greenie on a par 3 (radio: one per hole)
}

// CTP: closest to pin winner on par 3 holes (manual select)
export interface CtpHoleState {
  winnerId: string | null; // player who was closest to pin on this par 3
}

export interface HoleExtras {
  wolf?: WolfHoleState;
  bbb?: BBBHoleState;
  snake?: SnakeHoleState;
  dots?: DotsHoleState;
  ctp?: CtpHoleState;
  trouble?: TroubleHoleState;
  arnies?: ArniesHoleState;
  banker?: BankerHoleState;
}

// ─── Press Match (Nassau auto-press side bets) ──────────────────────────────

export interface PressMatch {
  id: string;
  leg: 'front' | 'back' | 'full';
  startHole: number; // 0-indexed, first hole of this press
  endHole: number;   // last hole of this leg (8 for front, 17 for back, 17 for full)
}

// ─── Game Extras (per-round tracking) ───────────────────────────────────────

export interface GameExtras {
  wolf?: (WolfHoleState | null)[];
  bbb?: (BBBHoleState | null)[];
  snake?: (SnakeHoleState | null)[];
  dots?: (DotsHoleState | null)[];
  ctp?: (CtpHoleState | null)[];
  pressMatches?: PressMatch[];
  hammerMultipliers?: number[]; // per-hole hammer multipliers (1, 2, 4, 8...)
  pars?: number[];              // par values per hole (for Vegas calculation)
  trouble?: (TroubleHoleState | null)[];
  arnies?: (ArniesHoleState | null)[];
  banker?: (BankerHoleState | null)[];
}

// ─── Results ────────────────────────────────────────────────────────────────

export interface Payout {
  from: string; // player name
  to: string;   // player name
  amount: number;
  game: GameMode; // which game this payout is from
}

export interface LeaderboardEntry {
  rank: number;
  name: string;
  total: number;
}

export interface GameResult {
  mode: GameMode;
  label: string;       // "Tax Man", "Nassau", etc.
  payouts: Payout[];
  net: Record<string, number>; // net per player name for this game
  leaderboard?: LeaderboardEntry[]; // for scorecard mode
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

// ─── Saved Players & Round History ──────────────────────────────────────────

export interface SavedPlayer {
  id: string;       // generateId()
  name: string;
  taxMan: number;
  handicap?: number;
}

export interface RoundRecord {
  id: string;
  date: string;              // ISO timestamp (new Date().toISOString())
  players: Player[];
  games: GameConfig[];
  scores: Record<string, (number | null)[]>;  // playerId -> 18 hole scores
  pars: number[];            // 18 par values
  results: MultiGameResults;
}
