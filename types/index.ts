export interface Player {
  id: string;
  name: string;
  taxMan: number;
}

export interface GameSetup {
  players: Player[];
  taxAmount: number;
}

export interface PlayerResult {
  player: Player;
  score: number;
  beatTaxMan: boolean; // score < taxMan => winner
}

export interface Payout {
  from: string; // player name
  to: string;   // player name
  amount: number;
}
