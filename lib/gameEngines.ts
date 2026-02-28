import {
  AcesDeucesConfig,
  BBBHoleState,
  BestBallConfig,
  BingoBangoBongoConfig,
  CtpConfig,
  CtpHoleState,
  DotsConfig,
  DotsHoleState,
  GameConfig,
  GameExtras,
  GameMode,
  GameResult,
  GameSetup,
  MultiGameResults,
  NassauConfig,
  NinesConfig,
  Payout,
  Player,
  PressMatch,
  RabbitConfig,
  ScorecardConfig,
  ScotchConfig,
  SixesConfig,
  SkinsConfig,
  SnakeConfig,
  SnakeHoleState,
  StablefordConfig,
  TaxManConfig,
  VegasConfig,
  WolfConfig,
  WolfHoleState,
} from '../types';

// Re-export GameExtras for backwards compatibility
export type { GameExtras } from '../types';

// ─── Live Status Types ──────────────────────────────────────────────────────

export interface LiveStatus {
  mode: GameMode;
  label: string;       // short game name
  lines: LiveStatusLine[];
}

export interface LiveStatusLine {
  text: string;        // e.g. "+2 F9", "Bobby 🐍", "3 skins"
  color: 'green' | 'red' | 'neutral' | 'yellow';
  playerId?: string;   // which player this line refers to (optional)
}

// ─── Helper functions ───────────────────────────────────────────────────────

function initNet(players: Player[]): Record<string, number> {
  const net: Record<string, number> = {};
  for (const p of players) {
    net[p.name] = 0;
  }
  return net;
}

function sumScores(scores: (number | null)[], start: number, end: number): number | null {
  let sum = 0;
  for (let i = start; i < end; i++) {
    if (scores[i] === null) return null;
    sum += scores[i]!;
  }
  return sum;
}

// ─── Handicap Helpers ───────────────────────────────────────────────────────

// Standard USGA-style hole handicap indices for 18 holes
// Index = hole number (0-based), value = difficulty rank (1=hardest, 18=easiest)
const HOLE_HANDICAP_STROKES = [1, 10, 2, 11, 3, 12, 4, 13, 5, 14, 6, 15, 7, 16, 8, 17, 9, 18];

function getHandicapAllowances(players: Player[]): Record<string, number> {
  // Find minimum handicap in group
  const minHcp = Math.min(...players.map(p => p.handicap ?? 0));
  // Each player's allowance = their handicap - min handicap
  return Object.fromEntries(players.map(p => [p.id, (p.handicap ?? 0) - minHcp]));
}

function getNetScore(grossScore: number | null, playerAllowance: number, hole: number): number | null {
  if (grossScore === null) return null;
  // Does this player get a stroke on this hole?
  const holeDifficulty = HOLE_HANDICAP_STROKES[hole]; // 1-18
  const strokesOnThisHole = playerAllowance >= holeDifficulty ? 1 : 0;
  return grossScore - strokesOnThisHole;
}

// ─── Tax Man ────────────────────────────────────────────────────────────────

export function calcTaxMan(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: TaxManConfig
): GameResult {
  const payouts: Payout[] = [];
  const net = initNet(players);

  // Determine winners and losers
  const winners: Player[] = [];
  const losers: Player[] = [];

  for (const player of players) {
    const total = sumScores(scores[player.id], 0, 18);
    if (total === null) continue; // incomplete
    
    if (total > 0 && total < player.taxMan) {
      winners.push(player);
    } else {
      losers.push(player);
    }
  }

  // Each loser pays each winner
  for (const loser of losers) {
    for (const winner of winners) {
      payouts.push({
        from: loser.name,
        to: winner.name,
        amount: config.taxAmount,
        game: 'taxman',
      });
      net[loser.name] -= config.taxAmount;
      net[winner.name] += config.taxAmount;
    }
  }

  return {
    mode: 'taxman',
    label: 'Tax Man',
    payouts,
    net,
  };
}

// ─── Nassau ─────────────────────────────────────────────────────────────────

function calcNassauStroke(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: NassauConfig
): { payouts: Payout[]; net: Record<string, number> } {
  const payouts: Payout[] = [];
  const net = initNet(players);
  
  // Handicap allowances (if enabled)
  const allowances = config.useHandicaps ? getHandicapAllowances(players) : {};

  const legs: { name: string; start: number; end: number }[] = [
    { name: 'Front 9', start: 0, end: 9 },
    { name: 'Back 9', start: 9, end: 18 },
    { name: 'Full 18', start: 0, end: 18 },
  ];

  for (const leg of legs) {
    // Calculate totals for each player for this leg (net if handicaps enabled)
    const totals: { player: Player; total: number }[] = [];
    
    for (const player of players) {
      if (config.useHandicaps) {
        // Calculate net total for this leg
        let netTotal = 0;
        let complete = true;
        for (let h = leg.start; h < leg.end; h++) {
          const gross = scores[player.id][h];
          if (gross === null) {
            complete = false;
            break;
          }
          const netScore = getNetScore(gross, allowances[player.id] ?? 0, h);
          netTotal += netScore ?? 0;
        }
        if (complete) {
          totals.push({ player, total: netTotal });
        }
      } else {
        const total = sumScores(scores[player.id], leg.start, leg.end);
        if (total !== null) {
          totals.push({ player, total });
        }
      }
    }

    if (totals.length < 2) continue; // Need at least 2 players with scores

    // Find lowest score
    const minScore = Math.min(...totals.map(t => t.total));
    const winners = totals.filter(t => t.total === minScore);

    // If multiple players tie for lowest, it's a push (no payout)
    if (winners.length > 1) continue;

    const winner = winners[0].player;
    
    // Winner receives betAmount from each other player
    for (const t of totals) {
      if (t.player.id !== winner.id) {
        payouts.push({
          from: t.player.name,
          to: winner.name,
          amount: config.betAmount,
          game: 'nassau',
        });
        net[t.player.name] -= config.betAmount;
        net[winner.name] += config.betAmount;
      }
    }
  }

  return { payouts, net };
}

// Helper to calculate match play result for a range of holes
function calcMatchPlayRange(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  start: number,
  end: number,
  useHandicaps: boolean,
  allowances: Record<string, number>
): { holesWon: Record<string, number>; participating: Player[] } {
  const holesWon: Record<string, number> = {};
  for (const p of players) {
    holesWon[p.id] = 0;
  }

  for (let hole = start; hole <= end; hole++) {
    // Get scores for this hole (net if handicaps enabled)
    const holeScores: { player: Player; score: number }[] = [];
    
    for (const player of players) {
      const gross = scores[player.id][hole];
      if (gross !== null) {
        const score = useHandicaps
          ? getNetScore(gross, allowances[player.id] ?? 0, hole)!
          : gross;
        holeScores.push({ player, score });
      }
    }

    if (holeScores.length < 2) continue;

    const minScore = Math.min(...holeScores.map(h => h.score));
    const holeWinners = holeScores.filter(h => h.score === minScore);

    if (holeWinners.length === 1) {
      holesWon[holeWinners[0].player.id]++;
    }
  }

  const participating = players.filter(p => {
    for (let h = start; h <= end; h++) {
      if (scores[p.id][h] !== null) return true;
    }
    return false;
  });

  return { holesWon, participating };
}

function calcNassauMatch(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: NassauConfig,
  pressMatches?: PressMatch[]
): { payouts: Payout[]; net: Record<string, number> } {
  const payouts: Payout[] = [];
  const net = initNet(players);
  
  // Handicap allowances (if enabled)
  const allowances = config.useHandicaps ? getHandicapAllowances(players) : {};

  const legs: { name: string; key: 'front' | 'back' | 'full'; start: number; end: number }[] = [
    { name: 'Front 9', key: 'front', start: 0, end: 8 },
    { name: 'Back 9', key: 'back', start: 9, end: 17 },
    { name: 'Full 18', key: 'full', start: 0, end: 17 },
  ];

  for (const leg of legs) {
    const { holesWon, participating } = calcMatchPlayRange(
      players, scores, leg.start, leg.end, config.useHandicaps, allowances
    );

    if (participating.length < 2) continue;

    const maxHolesWon = Math.max(...participating.map(p => holesWon[p.id]));
    if (maxHolesWon === 0) continue;

    const legWinners = participating.filter(p => holesWon[p.id] === maxHolesWon);

    if (legWinners.length > 1) continue; // Push

    const winner = legWinners[0];

    for (const other of participating) {
      if (other.id !== winner.id) {
        payouts.push({
          from: other.name,
          to: winner.name,
          amount: config.betAmount,
          game: 'nassau',
        });
        net[other.name] -= config.betAmount;
        net[winner.name] += config.betAmount;
      }
    }
  }

  // Process press bets
  if (pressMatches && pressMatches.length > 0) {
    // Group presses by leg for labeling
    const pressCountByLeg: Record<string, number> = { front: 0, back: 0, full: 0 };

    for (const press of pressMatches) {
      pressCountByLeg[press.leg]++;
      const pressNum = pressCountByLeg[press.leg];
      const labelSuffix = pressNum === 1 ? '' : ` ${pressNum}`;
      const legLabel = press.leg === 'front' ? 'F9' : press.leg === 'back' ? 'B9' : '18';

      const { holesWon, participating } = calcMatchPlayRange(
        players, scores, press.startHole, press.endHole, config.useHandicaps, allowances
      );

      if (participating.length < 2) continue;

      const maxHolesWon = Math.max(...participating.map(p => holesWon[p.id]));
      if (maxHolesWon === 0) continue;

      const pressWinners = participating.filter(p => holesWon[p.id] === maxHolesWon);

      if (pressWinners.length > 1) continue; // Push

      const winner = pressWinners[0];

      for (const other of participating) {
        if (other.id !== winner.id) {
          payouts.push({
            from: other.name,
            to: winner.name,
            amount: config.betAmount,
            game: 'nassau',
          });
          net[other.name] -= config.betAmount;
          net[winner.name] += config.betAmount;
        }
      }
    }
  }

  return { payouts, net };
}

export function calcNassau(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: NassauConfig,
  pressMatches?: PressMatch[]
): GameResult {
  // Default to stroke play for backwards compatibility
  const mode = config.mode ?? 'stroke';
  
  const { payouts, net } = mode === 'match'
    ? calcNassauMatch(players, scores, config, pressMatches)
    : calcNassauStroke(players, scores, config);

  // Build label
  let label = mode === 'match' ? 'Nassau (Match)' : 'Nassau';
  if (config.useHandicaps) {
    label += ' w/ HCP';
  }

  return {
    mode: 'nassau',
    label,
    payouts,
    net,
  };
}

// ─── Skins ──────────────────────────────────────────────────────────────────

export function calcSkins(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: SkinsConfig
): GameResult {
  const payouts: Payout[] = [];
  const net = initNet(players);

  let carryover = 0;
  const skinsWon: Record<string, number> = {};
  for (const p of players) {
    skinsWon[p.id] = 0;
  }

  for (let hole = 0; hole < 18; hole++) {
    // Get scores for this hole
    const holeScores: { player: Player; score: number }[] = [];
    
    for (const player of players) {
      const score = scores[player.id][hole];
      if (score !== null) {
        holeScores.push({ player, score });
      }
    }

    if (holeScores.length < 2) {
      carryover++;
      continue;
    }

    // Find lowest score
    const minScore = Math.min(...holeScores.map(h => h.score));
    const winners = holeScores.filter(h => h.score === minScore);

    if (winners.length === 1) {
      // Single winner takes the skin(s)
      const winner = winners[0].player;
      const skinCount = 1 + carryover;
      skinsWon[winner.id] += skinCount;
      carryover = 0;
    } else {
      // Tie — skin carries over
      carryover++;
    }
  }

  // Calculate payouts: for each skin won by player A, every other player pays betPerSkin to A
  for (const winner of players) {
    const skins = skinsWon[winner.id];
    if (skins > 0) {
      for (const other of players) {
        if (other.id !== winner.id) {
          const amount = skins * config.betPerSkin;
          payouts.push({
            from: other.name,
            to: winner.name,
            amount,
            game: 'skins',
          });
          net[other.name] -= amount;
          net[winner.name] += amount;
        }
      }
    }
  }

  return {
    mode: 'skins',
    label: 'Skins',
    payouts,
    net,
  };
}

// ─── Wolf ───────────────────────────────────────────────────────────────────

export function calcWolf(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  wolfHoles: (WolfHoleState | null)[],
  config: WolfConfig
): GameResult {
  const payouts: Payout[] = [];
  const net = initNet(players);

  for (let hole = 0; hole < 18; hole++) {
    const wolfState = wolfHoles[hole];
    if (!wolfState) continue; // Wolf not set for this hole

    const wolf = players.find(p => p.id === wolfState.wolfPlayerId);
    if (!wolf) continue;

    // Get all scores for this hole
    const holeScores: Record<string, number | null> = {};
    for (const p of players) {
      holeScores[p.id] = scores[p.id][hole];
    }

    // Check if we have all scores
    const allScored = players.every(p => holeScores[p.id] !== null);
    if (!allScored) continue;

    const wolfScore = holeScores[wolf.id]!;

    if (wolfState.partnerId === null) {
      // Lone Wolf: Wolf vs everyone else
      const others = players.filter(p => p.id !== wolf.id);
      const bestOtherScore = Math.min(...others.map(p => holeScores[p.id]!));

      if (wolfScore < bestOtherScore) {
        // Wolf wins: collect betPerHole from each opponent
        for (const other of others) {
          payouts.push({
            from: other.name,
            to: wolf.name,
            amount: config.betPerHole,
            game: 'wolf',
          });
          net[other.name] -= config.betPerHole;
          net[wolf.name] += config.betPerHole;
        }
      } else if (wolfScore > bestOtherScore) {
        // Wolf loses: pay 2× betPerHole to each opponent
        for (const other of others) {
          payouts.push({
            from: wolf.name,
            to: other.name,
            amount: config.betPerHole * 2,
            game: 'wolf',
          });
          net[wolf.name] -= config.betPerHole * 2;
          net[other.name] += config.betPerHole * 2;
        }
      }
      // Tie = push (no payout)
    } else {
      // 2v2: Wolf + partner vs others
      const partner = players.find(p => p.id === wolfState.partnerId);
      if (!partner) continue;

      const wolfTeam = [wolf, partner];
      const otherTeam = players.filter(p => p.id !== wolf.id && p.id !== partner.id);

      const wolfTeamScore = wolfScore + holeScores[partner.id]!;
      const otherTeamScore = otherTeam.reduce((sum, p) => sum + holeScores[p.id]!, 0);

      if (wolfTeamScore < otherTeamScore) {
        // Wolf team wins
        for (const winner of wolfTeam) {
          for (const loser of otherTeam) {
            payouts.push({
              from: loser.name,
              to: winner.name,
              amount: config.betPerHole,
              game: 'wolf',
            });
            net[loser.name] -= config.betPerHole;
            net[winner.name] += config.betPerHole;
          }
        }
      } else if (wolfTeamScore > otherTeamScore) {
        // Other team wins
        for (const winner of otherTeam) {
          for (const loser of wolfTeam) {
            payouts.push({
              from: loser.name,
              to: winner.name,
              amount: config.betPerHole,
              game: 'wolf',
            });
            net[loser.name] -= config.betPerHole;
            net[winner.name] += config.betPerHole;
          }
        }
      }
      // Tie = push
    }
  }

  return {
    mode: 'wolf',
    label: 'Wolf',
    payouts,
    net,
  };
}

// ─── Bingo Bango Bongo ──────────────────────────────────────────────────────

export function calcBBB(
  players: Player[],
  bbbHoles: (BBBHoleState | null)[],
  config: BingoBangoBongoConfig
): GameResult {
  const payouts: Payout[] = [];
  const net = initNet(players);

  // Count points per player
  const points: Record<string, number> = {};
  for (const p of players) {
    points[p.id] = 0;
  }

  for (let hole = 0; hole < 18; hole++) {
    const bbbState = bbbHoles[hole];
    if (!bbbState) continue;

    if (bbbState.bingoPlayerId) points[bbbState.bingoPlayerId]++;
    if (bbbState.bangoPlayerId) points[bbbState.bangoPlayerId]++;
    if (bbbState.bongoPlayerId) points[bbbState.bongoPlayerId]++;
  }

  // Find highest points
  const maxPoints = Math.max(...Object.values(points));
  if (maxPoints === 0) {
    return { mode: 'bingo-bango-bongo', label: 'Bingo Bango Bongo', payouts, net };
  }

  const winners = players.filter(p => points[p.id] === maxPoints);

  // Each non-winner pays each winner based on point differential
  for (const winner of winners) {
    for (const other of players) {
      if (other.id !== winner.id && !winners.some(w => w.id === other.id)) {
        const diff = points[winner.id] - points[other.id];
        const amount = diff * config.betPerPoint / winners.length; // Split among tied winners
        
        payouts.push({
          from: other.name,
          to: winner.name,
          amount,
          game: 'bingo-bango-bongo',
        });
        net[other.name] -= amount;
        net[winner.name] += amount;
      }
    }
  }

  return {
    mode: 'bingo-bango-bongo',
    label: 'Bingo Bango Bongo',
    payouts,
    net,
  };
}

// ─── Scorecard ──────────────────────────────────────────────────────────────

export function calcScorecard(
  players: Player[],
  scores: Record<string, (number | null)[]>
): GameResult {
  // Build a leaderboard: players ranked by total score (lowest wins in golf)
  // No payouts — this is just score tracking
  const net = initNet(players); // all zeros
  
  // Calculate totals for each player
  const playerScores = players.map(p => {
    const total = scores[p.id].reduce<number>((a, b) => a + (b ?? 0), 0);
    return { name: p.name, total };
  });
  
  // Sort by total score ascending (lowest = best in golf)
  playerScores.sort((a, b) => a.total - b.total);
  
  // Build leaderboard with ranks (handle ties)
  const leaderboard = playerScores.map((ps, idx) => {
    // If tied with previous player, use same rank
    const rank = idx > 0 && playerScores[idx - 1].total === ps.total
      ? playerScores.findIndex(p => p.total === ps.total) + 1
      : idx + 1;
    return {
      rank,
      name: ps.name,
      total: ps.total,
    };
  });
  
  // No payouts for scorecard mode
  return {
    mode: 'scorecard',
    label: 'Scorecard',
    payouts: [],
    net,
    leaderboard,
  };
}

// ─── Snake ──────────────────────────────────────────────────────────────────

export function calcSnake(
  players: Player[],
  snakeHoles: (SnakeHoleState | null)[],
  config: SnakeConfig
): GameResult {
  const payouts: Payout[] = [];
  const net = initNet(players);

  // Find who holds the snake at the end
  let currentHolder: string | null = null;

  for (let hole = 0; hole < 18; hole++) {
    const snakeState = snakeHoles[hole];
    if (!snakeState) continue;

    // If anyone 3-putted this hole, the last one to 3-putt holds the snake
    if (snakeState.threeputters.length > 0) {
      currentHolder = snakeState.threeputters[snakeState.threeputters.length - 1];
    }
  }

  // Snake holder pays snakeAmount to everyone else
  if (currentHolder) {
    const holder = players.find(p => p.id === currentHolder);
    if (holder) {
      for (const other of players) {
        if (other.id !== holder.id) {
          payouts.push({
            from: holder.name,
            to: other.name,
            amount: config.snakeAmount,
            game: 'snake',
          });
          net[holder.name] -= config.snakeAmount;
          net[other.name] += config.snakeAmount;
        }
      }
    }
  }

  return {
    mode: 'snake',
    label: 'Snake',
    payouts,
    net,
  };
}

// ─── Vegas ───────────────────────────────────────────────────────────────────

/** Concatenated team score: high digit first by default; low first if either player made par or better. */
function vegasTeamNumber(s1: number, s2: number, par: number, forceHigh = false): number {
  const lo = Math.min(s1, s2);
  const hi = Math.max(s1, s2);
  const hasDouble = s1 >= 10 || s2 >= 10;

  if (hasDouble) {
    // Double-digit always goes second (high first maintained)
    return parseInt(`${hi}${lo}`, 10);
  }

  const eitherParOrBetter = !forceHigh && (s1 <= par || s2 <= par);
  if (eitherParOrBetter) {
    return lo * 10 + hi; // low first = better (reward for par/birdie)
  }
  return hi * 10 + lo; // high first = default / penalty
}

export function calcVegas(
  players: Player[],
  allScores: Record<string, (number | null)[]>,
  pars: number[],
  config: VegasConfig,
  hammerMultipliers?: number[]
): GameResult {
  const { betPerPoint, flipBird, useHammer, teamA, teamB } = config;
  const net = initNet(players);

  const teamAPlayers = players.filter(p => teamA.includes(p.id));
  const teamBPlayers = players.filter(p => teamB.includes(p.id));

  if (teamAPlayers.length < 1 || teamBPlayers.length < 1) {
    return { mode: 'vegas', label: 'Vegas', payouts: [], net };
  }

  let teamANetPoints = 0;
  let teamBNetPoints = 0;

  for (let hole = 0; hole < 18; hole++) {
    const aScores = teamAPlayers.map(p => allScores[p.id]?.[hole] ?? null);
    const bScores = teamBPlayers.map(p => allScores[p.id]?.[hole] ?? null);

    if (aScores.some(s => s === null) || bScores.some(s => s === null)) continue;

    const as = aScores as number[];
    const bs = bScores as number[];
    const par = pars[hole];

    const aBirdie = as.some(s => s <= par - 1);
    const bBirdie = bs.some(s => s <= par - 1);

    // Compute base team numbers
    let numA = vegasTeamNumber(as[0], as[1] ?? as[0], par);
    let numB = vegasTeamNumber(bs[0], bs[1] ?? bs[0], par);

    // Birdie flip: winning birdie team forces opponent to high-first (worse score)
    if (flipBird) {
      if (aBirdie && !bBirdie) {
        numB = vegasTeamNumber(bs[0], bs[1] ?? bs[0], par, true); // force B high-first
      } else if (bBirdie && !aBirdie) {
        numA = vegasTeamNumber(as[0], as[1] ?? as[0], par, true); // force A high-first
      }
      // Both birdie → cancel (no flip)
    }

    const diff = Math.abs(numA - numB);
    const multiplier = useHammer ? (hammerMultipliers?.[hole] ?? 1) : 1;
    const points = diff * multiplier;

    if (numA < numB) {
      teamANetPoints += points;
      teamBNetPoints -= points;
    } else if (numB < numA) {
      teamBNetPoints += points;
      teamANetPoints -= points;
    }
    // equal → no points
  }

  const payouts: Payout[] = [];
  const payout = Math.round(Math.abs(teamANetPoints) * betPerPoint * 100) / 100;

  if (payout > 0) {
    const winners = teamANetPoints > 0 ? teamAPlayers : teamBPlayers;
    const losers  = teamANetPoints > 0 ? teamBPlayers : teamAPlayers;
    const share = payout / Math.max(winners.length, 1);

    for (const w of winners) {
      for (const l of losers) {
        payouts.push({ from: l.name, to: w.name, amount: share, game: 'vegas' });
      }
      net[w.name] = (net[w.name] ?? 0) + share * losers.length;
    }
    for (const l of losers) {
      net[l.name] = (net[l.name] ?? 0) - share * winners.length;
    }
  }

  return { mode: 'vegas', label: 'Vegas', payouts, net };
}

// ─── Best Ball ───────────────────────────────────────────────────────────────

export function calcBestBall(
  players: Player[],
  allScores: Record<string, (number | null)[]>,
  config: BestBallConfig
): GameResult {
  const { mode, betAmount, teamA, teamB } = config;
  const net = initNet(players);
  const payouts: Payout[] = [];

  const teamAPlayers = players.filter(p => teamA.includes(p.id));
  const teamBPlayers = players.filter(p => teamB.includes(p.id));

  if (teamAPlayers.length < 1 || teamBPlayers.length < 1) {
    return { mode: 'best-ball', label: 'Best Ball', payouts: [], net };
  }

  if (mode === 'stroke') {
    // Best ball total over 18: take lowest score per hole per team, sum them
    let totalA = 0;
    let totalB = 0;
    let holesComplete = 0;

    for (let hole = 0; hole < 18; hole++) {
      const aScores = teamAPlayers.map(p => allScores[p.id]?.[hole]).filter((s): s is number => s !== null && s !== undefined);
      const bScores = teamBPlayers.map(p => allScores[p.id]?.[hole]).filter((s): s is number => s !== null && s !== undefined);
      if (aScores.length === 0 || bScores.length === 0) continue;
      totalA += Math.min(...aScores);
      totalB += Math.min(...bScores);
      holesComplete++;
    }

    if (holesComplete === 0) return { mode: 'best-ball', label: 'Best Ball', payouts: [], net };

    const diff = Math.abs(totalA - totalB);
    const payout = Math.round(diff * betAmount * 100) / 100;

    if (payout > 0) {
      const winners = totalA < totalB ? teamAPlayers : teamBPlayers;
      const losers  = totalA < totalB ? teamBPlayers : teamAPlayers;
      const share = Math.round((payout / Math.max(winners.length, 1)) * 100) / 100;

      for (const w of winners) {
        for (const l of losers) {
          payouts.push({ from: l.name, to: w.name, amount: share, game: 'best-ball' });
        }
        net[w.name] = (net[w.name] ?? 0) + share * losers.length;
      }
      for (const l of losers) {
        net[l.name] = (net[l.name] ?? 0) - share * winners.length;
      }
    }

  } else {
    // Match play: hole-by-hole, best score wins; betAmount per hole won
    let holesA = 0;
    let holesB = 0;

    for (let hole = 0; hole < 18; hole++) {
      const aScores = teamAPlayers.map(p => allScores[p.id]?.[hole]).filter((s): s is number => s !== null && s !== undefined);
      const bScores = teamBPlayers.map(p => allScores[p.id]?.[hole]).filter((s): s is number => s !== null && s !== undefined);
      if (aScores.length === 0 || bScores.length === 0) continue;
      const bestA = Math.min(...aScores);
      const bestB = Math.min(...bScores);
      if (bestA < bestB) holesA++;
      else if (bestB < bestA) holesB++;
      // tie: no hole awarded
    }

    const diff = Math.abs(holesA - holesB);
    const payout = Math.round(diff * betAmount * 100) / 100;

    if (payout > 0) {
      const winners = holesA > holesB ? teamAPlayers : teamBPlayers;
      const losers  = holesA > holesB ? teamBPlayers : teamAPlayers;
      const share = Math.round((payout / Math.max(winners.length, 1)) * 100) / 100;

      for (const w of winners) {
        for (const l of losers) {
          payouts.push({ from: l.name, to: w.name, amount: share, game: 'best-ball' });
        }
        net[w.name] = (net[w.name] ?? 0) + share * losers.length;
      }
      for (const l of losers) {
        net[l.name] = (net[l.name] ?? 0) - share * winners.length;
      }
    }
  }

  return { mode: 'best-ball', label: 'Best Ball', payouts, net };
}

// ─── Stableford ──────────────────────────────────────────────────────────────

function stablefordPoints(score: number, par: number): number {
  const diff = score - par;
  if (diff <= -2) return 4; // Eagle or better
  if (diff === -1) return 3; // Birdie
  if (diff === 0)  return 2; // Par
  if (diff === 1)  return 1; // Bogey
  return 0;                  // Double bogey or worse
}

export function calcStableford(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  pars: number[],
  config: StablefordConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  const playerPoints = players.map(player => {
    let pts = 0;
    for (let h = 0; h < 18; h++) {
      const s = scores[player.id][h];
      if (s !== null) pts += stablefordPoints(s, pars[h]);
    }
    return { player, points: pts };
  });

  const maxPts = Math.max(...playerPoints.map(p => p.points));
  if (maxPts === 0) return { mode: 'stableford', label: 'Stableford', payouts, net };

  const winners = playerPoints.filter(p => p.points === maxPts);
  const losers  = playerPoints.filter(p => p.points < maxPts);

  for (const loser of losers) {
    for (const winner of winners) {
      const diff   = winner.points - loser.points;
      const amount = Math.round(config.betAmount * diff * 100) / 100;
      payouts.push({ from: loser.player.name, to: winner.player.name, amount, game: 'stableford' });
      net[loser.player.name]  -= amount;
      net[winner.player.name] += amount;
    }
  }

  return { mode: 'stableford', label: 'Stableford', payouts, net };
}

// ─── Rabbit ──────────────────────────────────────────────────────────────────

export function calcRabbit(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: RabbitConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  let rabbitHolder: string | null = null;

  for (let hole = 0; hole < 18; hole++) {
    const holeScores: { player: Player; score: number }[] = [];
    for (const player of players) {
      const s = scores[player.id][hole];
      if (s !== null) holeScores.push({ player, score: s });
    }
    if (holeScores.length < 2) continue;

    const minScore    = Math.min(...holeScores.map(h => h.score));
    const holeWinners = holeScores.filter(h => h.score === minScore);

    if (holeWinners.length === 1) {
      // Outright winner — catches the rabbit (or keeps it)
      rabbitHolder = holeWinners[0].player.id;
    }
    // Tie — rabbit stays with current holder
  }

  // Holder at end pays every other player rabbitAmount
  if (rabbitHolder !== null) {
    const holder = players.find(p => p.id === rabbitHolder);
    if (holder) {
      for (const other of players) {
        if (other.id !== holder.id) {
          payouts.push({ from: holder.name, to: other.name, amount: config.rabbitAmount, game: 'rabbit' });
          net[holder.name] -= config.rabbitAmount;
          net[other.name]  += config.rabbitAmount;
        }
      }
    }
  }

  return { mode: 'rabbit', label: 'Rabbit', payouts, net };
}

// ─── Dots / Junk ─────────────────────────────────────────────────────────────

export function calcDots(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  pars: number[],
  dotsHoles: (DotsHoleState | null)[],
  config: DotsConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  const dotsEarned: Record<string, number> = {};
  for (const p of players) dotsEarned[p.id] = 0;

  for (let hole = 0; hole < 18; hole++) {
    const par       = pars[hole];
    const holeState = dotsHoles[hole];

    for (const player of players) {
      const s = scores[player.id][hole];
      if (s === null) continue;

      const diff = s - par;

      if (config.eagle && diff <= -2) {
        dotsEarned[player.id] += 2;
      } else if (config.birdie && diff === -1) {
        dotsEarned[player.id] += 1;
      }

      if (config.sandy && holeState?.sandyPlayerIds.includes(player.id)) {
        dotsEarned[player.id] += 1;
      }
    }

    // Greenie: par 3 only — manual radio winner making par or better
    if (config.greenie && par === 3 && holeState?.greeniePlayerId) {
      const gScore = scores[holeState.greeniePlayerId]?.[hole];
      if (gScore !== null && gScore !== undefined && gScore <= par) {
        dotsEarned[holeState.greeniePlayerId] += 1;
      }
    }
  }

  // Each dot: every other player pays betPerDot to the earner
  for (const winner of players) {
    const d = dotsEarned[winner.id];
    if (d === 0) continue;
    for (const other of players) {
      if (other.id === winner.id) continue;
      const amount = Math.round(d * config.betPerDot * 100) / 100;
      payouts.push({ from: other.name, to: winner.name, amount, game: 'dots' });
      net[other.name]  -= amount;
      net[winner.name] += amount;
    }
  }

  return { mode: 'dots', label: 'Dots/Junk', payouts, net };
}

// ─── Sixes ────────────────────────────────────────────────────────────────────

export function calcSixes(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: SixesConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  if (players.length < 4) {
    return { mode: 'sixes', label: 'Sixes', payouts, net };
  }

  const [p0, p1, p2, p3] = players;

  const segments = [
    { start: 0,  end: 5,  teamA: [p0, p1], teamB: [p2, p3] },
    { start: 6,  end: 11, teamA: [p0, p2], teamB: [p1, p3] },
    { start: 12, end: 17, teamA: [p0, p3], teamB: [p1, p2] },
  ];

  for (const seg of segments) {
    let teamAWins = 0;
    let teamBWins = 0;

    for (let hole = seg.start; hole <= seg.end; hole++) {
      const aScores = seg.teamA
        .map(p => scores[p.id][hole])
        .filter((s): s is number => s !== null);
      const bScores = seg.teamB
        .map(p => scores[p.id][hole])
        .filter((s): s is number => s !== null);

      if (aScores.length === 0 || bScores.length === 0) continue;

      const bestA = Math.min(...aScores);
      const bestB = Math.min(...bScores);

      if (bestA < bestB) teamAWins++;
      else if (bestB < bestA) teamBWins++;
    }

    if (teamAWins === teamBWins) continue; // segment tied

    const winners = teamAWins > teamBWins ? seg.teamA : seg.teamB;
    const losers  = teamAWins > teamBWins ? seg.teamB : seg.teamA;

    for (const winner of winners) {
      for (const loser of losers) {
        payouts.push({ from: loser.name, to: winner.name, amount: config.betPerSegment, game: 'sixes' });
        net[loser.name]  -= config.betPerSegment;
        net[winner.name] += config.betPerSegment;
      }
    }
  }

  return { mode: 'sixes', label: 'Sixes', payouts, net };
}

// ─── Nines (Baseball) ────────────────────────────────────────────────────────

export function calcNines(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: NinesConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  // Accumulate total points per player
  const totalPoints: Record<string, number> = {};
  for (const p of players) totalPoints[p.id] = 0;

  for (let hole = 0; hole < 18; hole++) {
    const holeScores = players
      .map(p => ({ player: p, score: scores[p.id][hole] }))
      .filter((h): h is { player: Player; score: number } => h.score !== null);

    if (holeScores.length < 2) continue;

    // Sort by score ascending (best first)
    holeScores.sort((a, b) => a.score - b.score);

    // Distribute 9 points: 5-3-1 with tie splitting
    // Build score groups
    const groups: { score: number; players: Player[] }[] = [];
    for (const h of holeScores) {
      const last = groups[groups.length - 1];
      if (last && last.score === h.score) {
        last.players.push(h.player);
      } else {
        groups.push({ score: h.score, players: [h.player] });
      }
    }

    // Point buckets: for 3 players = [5, 3, 1]
    const buckets = [5, 3, 1].slice(0, groups.length);
    let bucketIdx = 0;
    for (const group of groups) {
      // How many buckets does this group consume?
      const consumed = group.players.length;
      const pooled = buckets.slice(bucketIdx, bucketIdx + consumed).reduce((a, b) => a + b, 0);
      const share = pooled / consumed;
      for (const p of group.players) {
        totalPoints[p.id] += share;
      }
      bucketIdx += consumed;
    }
  }

  // Payouts: each pair, higher points collects from lower points
  for (let i = 0; i < players.length; i++) {
    for (let j = i + 1; j < players.length; j++) {
      const a = players[i];
      const b = players[j];
      const diff = Math.abs(totalPoints[a.id] - totalPoints[b.id]);
      if (diff === 0) continue;
      const amount = Math.round(diff * config.betPerPoint * 100) / 100;
      const winner = totalPoints[a.id] > totalPoints[b.id] ? a : b;
      const loser  = totalPoints[a.id] > totalPoints[b.id] ? b : a;
      payouts.push({ from: loser.name, to: winner.name, amount, game: 'nines' });
      net[loser.name]  -= amount;
      net[winner.name] += amount;
    }
  }

  return { mode: 'nines', label: 'Nines', payouts, net };
}

// ─── Scotch (5-Point) ────────────────────────────────────────────────────────

export function calcScotch(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: ScotchConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  const teamAPlayers = players.filter(p => config.teamA.includes(p.id));
  const teamBPlayers = players.filter(p => config.teamB.includes(p.id));
  if (teamAPlayers.length < 2 || teamBPlayers.length < 2) {
    return { mode: 'scotch', label: 'Scotch', payouts, net };
  }

  let pointsA = 0;
  let pointsB = 0;

  for (let hole = 0; hole < 18; hole++) {
    const aScores = teamAPlayers.map(p => scores[p.id][hole]).filter((s): s is number => s !== null);
    const bScores = teamBPlayers.map(p => scores[p.id][hole]).filter((s): s is number => s !== null);
    if (aScores.length < 2 || bScores.length < 2) continue;

    const lowA = Math.min(...aScores);
    const lowB = Math.min(...bScores);
    const totalA = aScores.reduce((a, b) => a + b, 0);
    const totalB = bScores.reduce((a, b) => a + b, 0);

    // Low ball (2 pts) — lower individual score on team wins
    if (lowA < lowB) pointsA += 2;
    else if (lowB < lowA) pointsB += 2;
    // tie: 0 pts each

    // Low total (3 pts) — lower combined score wins
    if (totalA < totalB) pointsA += 3;
    else if (totalB < totalA) pointsB += 3;
    // tie: 0 pts each
  }

  const diff = Math.abs(pointsA - pointsB);
  const payout = Math.round(diff * config.betPerPoint * 100) / 100;

  if (payout > 0) {
    const winners = pointsA > pointsB ? teamAPlayers : teamBPlayers;
    const losers  = pointsA > pointsB ? teamBPlayers : teamAPlayers;
    const share = Math.round((payout / winners.length) * 100) / 100;

    for (const w of winners) {
      for (const l of losers) {
        payouts.push({ from: l.name, to: w.name, amount: share, game: 'scotch' });
      }
      net[w.name] += share * losers.length;
    }
    for (const l of losers) {
      net[l.name] -= share * winners.length;
    }
  }

  return { mode: 'scotch', label: 'Scotch', payouts, net };
}

// ─── Closest to the Pin (CTP) ────────────────────────────────────────────────

export function calcCtp(
  players: Player[],
  pars: number[],
  ctpHoles: (CtpHoleState | null)[],
  config: CtpConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  for (let hole = 0; hole < 18; hole++) {
    if (pars[hole] !== 3) continue; // CTP only on par 3s
    const state = ctpHoles[hole];
    if (!state?.winnerId) continue;

    const winner = players.find(p => p.id === state.winnerId);
    if (!winner) continue;

    for (const other of players) {
      if (other.id === winner.id) continue;
      payouts.push({ from: other.name, to: winner.name, amount: config.betAmount, game: 'ctp' });
      net[other.name]  -= config.betAmount;
      net[winner.name] += config.betAmount;
    }
  }

  return { mode: 'ctp', label: 'CTP', payouts, net };
}

// ─── Aces & Deuces ───────────────────────────────────────────────────────────

export function calcAcesDeuces(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: AcesDeucesConfig
): GameResult {
  const net = initNet(players);
  const payouts: Payout[] = [];

  for (let hole = 0; hole < 18; hole++) {
    const holeScores = players
      .map(p => ({ player: p, score: scores[p.id][hole] }))
      .filter((h): h is { player: Player; score: number } => h.score !== null);

    if (holeScores.length < 2) continue;

    const scores_arr = holeScores.map(h => h.score);
    const minScore = Math.min(...scores_arr);
    const maxScore = Math.max(...scores_arr);

    // If everyone ties: push
    if (minScore === maxScore) continue;

    const aces   = holeScores.filter(h => h.score === minScore).map(h => h.player);
    const deuces = holeScores.filter(h => h.score === maxScore).map(h => h.player);

    // Each ace collects betPerHole from each deuce
    for (const ace of aces) {
      for (const deuce of deuces) {
        payouts.push({ from: deuce.name, to: ace.name, amount: config.betPerHole, game: 'aces-deuces' });
        net[deuce.name] -= config.betPerHole;
        net[ace.name]   += config.betPerHole;
      }
    }
  }

  return { mode: 'aces-deuces', label: 'Aces & Deuces', payouts, net };
}

// ─── Master: Calculate all active games ─────────────────────────────────────

export function calcAllGames(
  setup: GameSetup,
  scores: Record<string, (number | null)[]>,
  extras: GameExtras
): MultiGameResults {
  const { players, games } = setup;
  const playerNames = players.map(p => p.name);
  const gameResults: GameResult[] = [];
  const combinedNet: Record<string, number> = {};

  for (const name of playerNames) {
    combinedNet[name] = 0;
  }

  for (const game of games) {
    let result: GameResult;

    switch (game.mode) {
      case 'taxman':
        result = calcTaxMan(players, scores, game.config);
        break;
      case 'nassau':
        result = calcNassau(players, scores, game.config, extras.pressMatches);
        break;
      case 'skins':
        result = calcSkins(players, scores, game.config);
        break;
      case 'wolf':
        result = calcWolf(players, scores, extras.wolf ?? [], game.config);
        break;
      case 'bingo-bango-bongo':
        result = calcBBB(players, extras.bbb ?? [], game.config);
        break;
      case 'snake':
        result = calcSnake(players, extras.snake ?? [], game.config);
        break;
      case 'scorecard':
        result = calcScorecard(players, scores);
        break;
      case 'vegas':
        result = calcVegas(players, scores, extras.pars ?? Array(18).fill(4), game.config, extras.hammerMultipliers ?? []);
        break;
      case 'best-ball':
        result = calcBestBall(players, scores, game.config);
        break;
      case 'stableford':
        result = calcStableford(players, scores, extras.pars ?? Array(18).fill(4), game.config);
        break;
      case 'rabbit':
        result = calcRabbit(players, scores, game.config);
        break;
      case 'dots':
        result = calcDots(players, scores, extras.pars ?? Array(18).fill(4), extras.dots ?? [], game.config);
        break;
      case 'sixes':
        result = calcSixes(players, scores, game.config);
        break;
      case 'nines':
        result = calcNines(players, scores, game.config);
        break;
      case 'scotch':
        result = calcScotch(players, scores, game.config);
        break;
      case 'ctp':
        result = calcCtp(players, extras.pars ?? Array(18).fill(4), extras.ctp ?? [], game.config);
        break;
      case 'aces-deuces':
        result = calcAcesDeuces(players, scores, game.config);
        break;
    }

    gameResults.push(result);

    // Add to combined net
    for (const name of playerNames) {
      combinedNet[name] += result.net[name] ?? 0;
    }
  }

  return {
    playerNames,
    games: gameResults,
    combinedNet,
  };
}

// ─── Live Status Calculation ────────────────────────────────────────────────

function calcLiveScorecard(
  players: Player[],
  scores: Record<string, (number | null)[]>
): LiveStatus {
  // Calculate running totals for each player (count only entered scores)
  const playerTotals = players.map(p => {
    const entered = scores[p.id].filter(s => s !== null) as number[];
    const total = entered.reduce((a, b) => a + b, 0);
    return { id: p.id, name: p.name, total, holes: entered.length };
  });

  // Sort by total (lowest is best in golf)
  playerTotals.sort((a, b) => a.total - b.total);

  const lines: LiveStatusLine[] = playerTotals.map((pt, idx) => ({
    text: `${pt.name}: ${pt.total}`,
    color: idx === 0 && pt.holes > 0 ? 'green' : 'neutral',
    playerId: pt.id,
  }));

  return { mode: 'scorecard', label: '📋 Score', lines };
}

function calcLiveTaxMan(
  players: Player[],
  scores: Record<string, (number | null)[]>
): LiveStatus {
  const lines: LiveStatusLine[] = players.map(p => {
    const entered = scores[p.id].filter(s => s !== null) as number[];
    if (entered.length === 0) {
      return { text: `${p.name} --`, color: 'yellow' as const, playerId: p.id };
    }
    const total = entered.reduce((a, b) => a + b, 0);
    // Project to 18 holes if we have partial data
    const projected = entered.length < 18 
      ? Math.round((total / entered.length) * 18)
      : total;
    const diff = total - p.taxMan;
    const sign = diff >= 0 ? '+' : '';
    const symbol = diff < 0 ? '✓' : '✗';
    return {
      text: `${p.name} ${sign}${diff} ${symbol}`,
      color: diff < 0 ? 'green' : 'red',
      playerId: p.id,
    };
  });

  return { mode: 'taxman', label: '💰 Tax Man', lines };
}

function calcLiveNassauStroke(
  players: Player[],
  scores: Record<string, (number | null)[]>
): LiveStatus {
  const lines: LiveStatusLine[] = [];

  // Front 9 (holes 0-8)
  const f9Totals: { player: Player; total: number }[] = [];
  for (const p of players) {
    let total = 0;
    let complete = true;
    for (let i = 0; i < 9; i++) {
      if (scores[p.id][i] === null) {
        complete = false;
        break;
      }
      total += scores[p.id][i]!;
    }
    if (complete) f9Totals.push({ player: p, total });
  }

  if (f9Totals.length >= 2) {
    f9Totals.sort((a, b) => a.total - b.total);
    const best = f9Totals[0];
    const second = f9Totals[1];
    if (best.total === second.total) {
      lines.push({ text: 'F9: Tied', color: 'neutral' });
    } else {
      const diff = second.total - best.total;
      lines.push({ text: `F9: ${best.player.name} -${diff}`, color: 'green', playerId: best.player.id });
    }
  } else {
    lines.push({ text: 'F9: --', color: 'neutral' });
  }

  // Back 9 (holes 9-17)
  const b9Totals: { player: Player; total: number }[] = [];
  for (const p of players) {
    let total = 0;
    let complete = true;
    for (let i = 9; i < 18; i++) {
      if (scores[p.id][i] === null) {
        complete = false;
        break;
      }
      total += scores[p.id][i]!;
    }
    if (complete) b9Totals.push({ player: p, total });
  }

  if (b9Totals.length >= 2) {
    b9Totals.sort((a, b) => a.total - b.total);
    const best = b9Totals[0];
    const second = b9Totals[1];
    if (best.total === second.total) {
      lines.push({ text: 'B9: Tied', color: 'neutral' });
    } else {
      const diff = second.total - best.total;
      lines.push({ text: `B9: ${best.player.name} -${diff}`, color: 'green', playerId: best.player.id });
    }
  } else {
    lines.push({ text: 'B9: --', color: 'neutral' });
  }

  return { mode: 'nassau', label: '🏌️ Nassau', lines };
}

function calcLiveNassauMatch(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: NassauConfig,
  pressMatches?: PressMatch[]
): LiveStatus {
  const lines: LiveStatusLine[] = [];
  const allowances = config.useHandicaps ? getHandicapAllowances(players) : {};

  const calcLegStatus = (start: number, end: number, label: string) => {
    const holesWon: Record<string, number> = {};
    for (const p of players) holesWon[p.id] = 0;

    for (let hole = start; hole < end; hole++) {
      // Check if all players have scores for this hole
      const allScored = players.every(p => scores[p.id][hole] !== null);
      if (!allScored) continue;

      const holeScores = players.map(p => {
        const gross = scores[p.id][hole]!;
        const score = config.useHandicaps
          ? getNetScore(gross, allowances[p.id] ?? 0, hole)!
          : gross;
        return { player: p, score };
      });
      const minScore = Math.min(...holeScores.map(h => h.score));
      const winners = holeScores.filter(h => h.score === minScore);

      if (winners.length === 1) {
        holesWon[winners[0].player.id]++;
      }
    }

    const sorted = players
      .map(p => ({ player: p, won: holesWon[p.id] }))
      .sort((a, b) => b.won - a.won);

    if (sorted[0].won === 0) {
      return { text: `${label}: --`, color: 'neutral' as const };
    }

    if (sorted[0].won === sorted[1].won) {
      return { text: `${label}: AS`, color: 'neutral' as const };
    }

    const diff = sorted[0].won - sorted[1].won;
    const notation = diff === 1 ? '1UP' : `${diff}UP`;
    return { 
      text: `${label}: ${sorted[0].player.name} ${notation}`, 
      color: 'green' as const,
      playerId: sorted[0].player.id 
    };
  };

  lines.push(calcLegStatus(0, 9, 'F9'));
  lines.push(calcLegStatus(9, 18, 'B9'));

  // Show active press matches
  if (pressMatches && pressMatches.length > 0) {
    const activeF9Presses = pressMatches.filter(pm => pm.leg === 'front').length;
    const activeB9Presses = pressMatches.filter(pm => pm.leg === 'back').length;
    
    if (activeF9Presses > 0) {
      lines.push({ text: `F9: ${activeF9Presses} press${activeF9Presses > 1 ? 'es' : ''}`, color: 'yellow' });
    }
    if (activeB9Presses > 0) {
      lines.push({ text: `B9: ${activeB9Presses} press${activeB9Presses > 1 ? 'es' : ''}`, color: 'yellow' });
    }
  }

  const labelSuffix = config.useHandicaps ? ' w/ HCP' : '';
  return { mode: 'nassau', label: `🏌️ Nassau (Match)${labelSuffix}`, lines };
}

function calcLiveSkins(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: SkinsConfig
): LiveStatus {
  let carryover = 0;
  const skinsWon: Record<string, number> = {};
  for (const p of players) skinsWon[p.id] = 0;

  for (let hole = 0; hole < 18; hole++) {
    const holeScores: { player: Player; score: number }[] = [];
    for (const player of players) {
      const score = scores[player.id][hole];
      if (score !== null) {
        holeScores.push({ player, score });
      }
    }

    if (holeScores.length < 2) {
      carryover++;
      continue;
    }

    const minScore = Math.min(...holeScores.map(h => h.score));
    const winners = holeScores.filter(h => h.score === minScore);

    if (winners.length === 1) {
      skinsWon[winners[0].player.id] += 1 + carryover;
      carryover = 0;
    } else {
      carryover++;
    }
  }

  const lines: LiveStatusLine[] = players
    .filter(p => skinsWon[p.id] > 0)
    .map(p => ({
      text: `${p.name} ${skinsWon[p.id]} 🎰`,
      color: 'green' as const,
      playerId: p.id,
    }));

  if (carryover > 0) {
    lines.push({ text: `carry: ${carryover}`, color: 'yellow' });
  }

  if (lines.length === 0) {
    lines.push({ text: 'No skins yet', color: 'neutral' });
  }

  return { mode: 'skins', label: '🎰 Skins', lines };
}

function calcLiveWolf(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  wolfHoles: (WolfHoleState | null)[],
  config: WolfConfig
): LiveStatus {
  const net: Record<string, number> = {};
  for (const p of players) net[p.id] = 0;

  for (let hole = 0; hole < 18; hole++) {
    const wolfState = wolfHoles[hole];
    if (!wolfState) continue;

    const wolf = players.find(p => p.id === wolfState.wolfPlayerId);
    if (!wolf) continue;

    // Check all players have scores
    const allScored = players.every(p => scores[p.id][hole] !== null);
    if (!allScored) continue;

    const wolfScore = scores[wolf.id][hole]!;

    if (wolfState.partnerId === null) {
      // Lone Wolf
      const others = players.filter(p => p.id !== wolf.id);
      const bestOther = Math.min(...others.map(p => scores[p.id][hole]!));

      if (wolfScore < bestOther) {
        for (const other of others) {
          net[wolf.id] += config.betPerHole;
          net[other.id] -= config.betPerHole;
        }
      } else if (wolfScore > bestOther) {
        for (const other of others) {
          net[wolf.id] -= config.betPerHole * 2;
          net[other.id] += config.betPerHole * 2;
        }
      }
    } else {
      // 2v2
      const partner = players.find(p => p.id === wolfState.partnerId);
      if (!partner) continue;

      const wolfTeam = [wolf, partner];
      const otherTeam = players.filter(p => p.id !== wolf.id && p.id !== partner.id);

      const wolfTeamScore = wolfScore + scores[partner.id][hole]!;
      const otherTeamScore = otherTeam.reduce((sum, p) => sum + scores[p.id][hole]!, 0);

      if (wolfTeamScore < otherTeamScore) {
        for (const w of wolfTeam) {
          for (const o of otherTeam) {
            net[w.id] += config.betPerHole;
            net[o.id] -= config.betPerHole;
          }
        }
      } else if (wolfTeamScore > otherTeamScore) {
        for (const o of otherTeam) {
          for (const w of wolfTeam) {
            net[o.id] += config.betPerHole;
            net[w.id] -= config.betPerHole;
          }
        }
      }
    }
  }

  const lines: LiveStatusLine[] = players.map(p => {
    const val = net[p.id];
    const sign = val >= 0 ? '+' : '';
    return {
      text: `${p.name} ${sign}$${val}`,
      color: val > 0 ? 'green' : val < 0 ? 'red' : 'neutral',
      playerId: p.id,
    };
  });

  return { mode: 'wolf', label: '🐺 Wolf', lines };
}

function calcLiveBBB(
  players: Player[],
  bbbHoles: (BBBHoleState | null)[]
): LiveStatus {
  const points: Record<string, number> = {};
  for (const p of players) points[p.id] = 0;

  for (let hole = 0; hole < 18; hole++) {
    const state = bbbHoles[hole];
    if (!state) continue;
    if (state.bingoPlayerId) points[state.bingoPlayerId]++;
    if (state.bangoPlayerId) points[state.bangoPlayerId]++;
    if (state.bongoPlayerId) points[state.bongoPlayerId]++;
  }

  const sorted = players
    .map(p => ({ player: p, pts: points[p.id] }))
    .sort((a, b) => b.pts - a.pts);

  const maxPts = sorted[0]?.pts ?? 0;

  const lines: LiveStatusLine[] = sorted.map(s => ({
    text: `${s.player.name} ${s.pts}pts`,
    color: s.pts === maxPts && maxPts > 0 ? 'green' : 'neutral',
    playerId: s.player.id,
  }));

  return { mode: 'bingo-bango-bongo', label: '🎯 BBB', lines };
}

function calcLiveSnake(
  players: Player[],
  snakeHoles: (SnakeHoleState | null)[]
): LiveStatus {
  let currentHolder: string | null = null;
  let holesHeld = 0;

  for (let hole = 0; hole < 18; hole++) {
    const state = snakeHoles[hole];
    if (!state) continue;

    if (state.threeputters.length > 0) {
      const newHolder = state.threeputters[state.threeputters.length - 1];
      if (newHolder !== currentHolder) {
        currentHolder = newHolder;
        holesHeld = 1;
      } else {
        holesHeld++;
      }
    } else if (currentHolder) {
      holesHeld++;
    }
  }

  if (!currentHolder) {
    return { mode: 'snake', label: '🐍 Snake', lines: [{ text: 'No holder', color: 'neutral' }] };
  }

  const holder = players.find(p => p.id === currentHolder);
  return {
    mode: 'snake',
    label: '🐍 Snake',
    lines: [{ text: `🐍 ${holder?.name ?? '?'} (${holesHeld}h)`, color: 'red', playerId: currentHolder }],
  };
}

function calcLiveStableford(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  pars: number[]
): LiveStatus {
  const playerPoints = players.map(p => {
    let pts = 0;
    for (let h = 0; h < 18; h++) {
      const s = scores[p.id][h];
      if (s !== null) pts += stablefordPoints(s, pars[h]);
    }
    return { player: p, points: pts };
  });

  playerPoints.sort((a, b) => b.points - a.points);
  const maxPts = playerPoints[0]?.points ?? 0;

  const lines: LiveStatusLine[] = playerPoints.map(pp => ({
    text: `${pp.player.name} ${pp.points}pts`,
    color: pp.points === maxPts && maxPts > 0 ? 'green' : 'neutral',
    playerId: pp.player.id,
  }));

  return { mode: 'stableford', label: '🃏 Stableford', lines };
}

function calcLiveRabbit(
  players: Player[],
  scores: Record<string, (number | null)[]>
): LiveStatus {
  let rabbitHolder: string | null = null;

  for (let hole = 0; hole < 18; hole++) {
    const holeScores: { player: Player; score: number }[] = [];
    for (const player of players) {
      const s = scores[player.id][hole];
      if (s !== null) holeScores.push({ player, score: s });
    }
    if (holeScores.length < 2) continue;
    const minScore = Math.min(...holeScores.map(h => h.score));
    const winners  = holeScores.filter(h => h.score === minScore);
    if (winners.length === 1) rabbitHolder = winners[0].player.id;
  }

  if (!rabbitHolder) {
    return { mode: 'rabbit', label: '🐰 Rabbit', lines: [{ text: 'Uncaught', color: 'neutral' }] };
  }
  const holder = players.find(p => p.id === rabbitHolder);
  return {
    mode: 'rabbit',
    label: '🐰 Rabbit',
    lines: [{ text: `🐰 ${holder?.name ?? '?'} holds`, color: 'red', playerId: rabbitHolder }],
  };
}

function calcLiveDots(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  pars: number[],
  dotsHoles: (DotsHoleState | null)[],
  config: DotsConfig
): LiveStatus {
  const dotsEarned: Record<string, number> = {};
  for (const p of players) dotsEarned[p.id] = 0;

  for (let hole = 0; hole < 18; hole++) {
    const par       = pars[hole];
    const holeState = dotsHoles[hole];

    for (const player of players) {
      const s = scores[player.id][hole];
      if (s === null) continue;
      const diff = s - par;
      if (config.eagle && diff <= -2) dotsEarned[player.id] += 2;
      else if (config.birdie && diff === -1) dotsEarned[player.id] += 1;
      if (config.sandy && holeState?.sandyPlayerIds.includes(player.id)) dotsEarned[player.id] += 1;
    }

    if (config.greenie && par === 3 && holeState?.greeniePlayerId) {
      const gScore = scores[holeState.greeniePlayerId]?.[hole];
      if (gScore !== null && gScore !== undefined && gScore <= par) {
        dotsEarned[holeState.greeniePlayerId] += 1;
      }
    }
  }

  const sorted = players
    .map(p => ({ player: p, dots: dotsEarned[p.id] }))
    .sort((a, b) => b.dots - a.dots);
  const maxDots = sorted[0]?.dots ?? 0;

  const lines: LiveStatusLine[] = sorted.map(s => ({
    text: `${s.player.name} ${s.dots}🔵`,
    color: s.dots === maxDots && maxDots > 0 ? 'green' : 'neutral',
    playerId: s.player.id,
  }));

  return { mode: 'dots', label: '🗑️ Dots', lines };
}

function calcLiveSixes(
  players: Player[],
  scores: Record<string, (number | null)[]>
): LiveStatus {
  if (players.length < 4) {
    return { mode: 'sixes', label: '🔄 Sixes', lines: [{ text: 'Need 4 players', color: 'neutral' }] };
  }

  const [p0, p1, p2, p3] = players;
  const segments = [
    { label: 'S1', start: 0,  end: 5,  teamA: [p0, p1], teamB: [p2, p3] },
    { label: 'S2', start: 6,  end: 11, teamA: [p0, p2], teamB: [p1, p3] },
    { label: 'S3', start: 12, end: 17, teamA: [p0, p3], teamB: [p1, p2] },
  ];

  const lines: LiveStatusLine[] = [];

  for (const seg of segments) {
    let aWins = 0;
    let bWins = 0;
    let hasAnyScore = false;

    for (let hole = seg.start; hole <= seg.end; hole++) {
      const aS = seg.teamA.map(p => scores[p.id][hole]).filter((s): s is number => s !== null);
      const bS = seg.teamB.map(p => scores[p.id][hole]).filter((s): s is number => s !== null);
      if (aS.length === 0 || bS.length === 0) continue;
      hasAnyScore = true;
      const bestA = Math.min(...aS);
      const bestB = Math.min(...bS);
      if (bestA < bestB) aWins++;
      else if (bestB < bestA) bWins++;
    }

    if (!hasAnyScore) continue;

    const teamAName = seg.teamA.map(p => p.name.split(' ')[0]).join('/');
    const teamBName = seg.teamB.map(p => p.name.split(' ')[0]).join('/');

    if (aWins === bWins) {
      lines.push({ text: `${seg.label}: AS`, color: 'neutral' });
    } else if (aWins > bWins) {
      lines.push({ text: `${seg.label}: ${teamAName} ${aWins}-${bWins}`, color: 'green' });
    } else {
      lines.push({ text: `${seg.label}: ${teamBName} ${bWins}-${aWins}`, color: 'green' });
    }
  }

  if (lines.length === 0) lines.push({ text: 'In progress', color: 'neutral' });

  return { mode: 'sixes', label: '🔄 Sixes', lines };
}

function calcLiveNines(players: Player[], scores: Record<string, (number | null)[]>): LiveStatus {
  const pts: Record<string, number> = {};
  for (const p of players) pts[p.id] = 0;

  for (let h = 0; h < 18; h++) {
    const hs = players.map(p => ({ p, s: scores[p.id][h] })).filter((x): x is { p: Player; s: number } => x.s !== null);
    if (hs.length < 2) continue;
    hs.sort((a, b) => a.s - b.s);
    const groups: { s: number; ps: Player[] }[] = [];
    for (const { p, s } of hs) {
      const last = groups[groups.length - 1];
      if (last && last.s === s) last.ps.push(p); else groups.push({ s, ps: [p] });
    }
    const buckets = [5, 3, 1].slice(0, groups.length);
    let idx = 0;
    for (const g of groups) {
      const share = buckets.slice(idx, idx + g.ps.length).reduce((a, b) => a + b, 0) / g.ps.length;
      for (const p of g.ps) pts[p.id] += share;
      idx += g.ps.length;
    }
  }

  const sorted = players.map(p => ({ p, pts: pts[p.id] })).sort((a, b) => b.pts - a.pts);
  const max = sorted[0]?.pts ?? 0;
  const lines: LiveStatusLine[] = sorted.map(({ p, pts: pt }) => ({
    text: `${p.name} ${pt}pts`, color: pt === max && max > 0 ? 'green' : 'neutral', playerId: p.id,
  }));
  return { mode: 'nines', label: '⚾ Nines', lines };
}

function calcLiveScotch(players: Player[], scores: Record<string, (number | null)[]>, config: ScotchConfig): LiveStatus {
  const teamAPlayers = players.filter(p => config.teamA.includes(p.id));
  const teamBPlayers = players.filter(p => config.teamB.includes(p.id));
  let pA = 0; let pB = 0;
  for (let h = 0; h < 18; h++) {
    const aS = teamAPlayers.map(p => scores[p.id][h]).filter((s): s is number => s !== null);
    const bS = teamBPlayers.map(p => scores[p.id][h]).filter((s): s is number => s !== null);
    if (aS.length < 2 || bS.length < 2) continue;
    if (Math.min(...aS) < Math.min(...bS)) pA += 2; else if (Math.min(...bS) < Math.min(...aS)) pB += 2;
    if (aS.reduce((a,b)=>a+b,0) < bS.reduce((a,b)=>a+b,0)) pA += 3; else if (bS.reduce((a,b)=>a+b,0) < aS.reduce((a,b)=>a+b,0)) pB += 3;
  }
  const nA = teamAPlayers.map(p => p.name.split(' ')[0]).join('/');
  const nB = teamBPlayers.map(p => p.name.split(' ')[0]).join('/');
  const diff = pA - pB;
  const lines: LiveStatusLine[] = [
    diff === 0
      ? { text: `${nA} ${pA} — ${pB} ${nB}`, color: 'neutral' }
      : diff > 0
        ? { text: `${nA} leads ${pA}–${pB}`, color: 'green' }
        : { text: `${nB} leads ${pB}–${pA}`, color: 'green' },
  ];
  return { mode: 'scotch', label: '🤝 Scotch', lines };
}

function calcLiveCtp(players: Player[], pars: number[], ctpHoles: (CtpHoleState | null)[]): LiveStatus {
  const wins: Record<string, number> = {};
  for (const p of players) wins[p.id] = 0;
  for (let h = 0; h < 18; h++) {
    if (pars[h] !== 3) continue;
    const w = ctpHoles[h]?.winnerId;
    if (w) wins[w] = (wins[w] ?? 0) + 1;
  }
  const lines: LiveStatusLine[] = players
    .filter(p => wins[p.id] > 0)
    .map(p => ({ text: `${p.name} ${wins[p.id]} CTP`, color: 'green' as const, playerId: p.id }));
  if (lines.length === 0) lines.push({ text: 'No CTP yet', color: 'neutral' });
  return { mode: 'ctp', label: '⛳ CTP', lines };
}

function calcLiveAcesDeuces(players: Player[], scores: Record<string, (number | null)[]>, config: AcesDeucesConfig): LiveStatus {
  const net: Record<string, number> = {};
  for (const p of players) net[p.id] = 0;
  for (let h = 0; h < 18; h++) {
    const hs = players.map(p => ({ p, s: scores[p.id][h] })).filter((x): x is { p: Player; s: number } => x.s !== null);
    if (hs.length < 2) continue;
    const min = Math.min(...hs.map(x => x.s)); const max = Math.max(...hs.map(x => x.s));
    if (min === max) continue;
    const aces = hs.filter(x => x.s === min); const deuces = hs.filter(x => x.s === max);
    for (const ace of aces) for (const d of deuces) { net[ace.p.id] += config.betPerHole; net[d.p.id] -= config.betPerHole; }
  }
  const lines: LiveStatusLine[] = players.map(p => {
    const v = net[p.id]; const sign = v >= 0 ? '+' : '';
    return { text: `${p.name} ${sign}$${v}`, color: v > 0 ? 'green' : v < 0 ? 'red' : 'neutral', playerId: p.id };
  });
  return { mode: 'aces-deuces', label: '🎲 Aces & Deuces', lines };
}

export function calcLiveStatus(
  setup: GameSetup,
  scores: Record<string, (number | null)[]>,
  pars: number[],
  wolfHoles: (WolfHoleState | null)[],
  bbbHoles: (BBBHoleState | null)[],
  snakeHoles: (SnakeHoleState | null)[],
  pressMatches?: PressMatch[],
  dotsHoles?: (DotsHoleState | null)[],
  ctpHoles?: (CtpHoleState | null)[]
): LiveStatus[] {
  const results: LiveStatus[] = [];
  const { players, games } = setup;

  for (const game of games) {
    switch (game.mode) {
      case 'scorecard':
        results.push(calcLiveScorecard(players, scores));
        break;
      case 'taxman':
        results.push(calcLiveTaxMan(players, scores));
        break;
      case 'nassau':
        if (game.config.mode === 'match') {
          results.push(calcLiveNassauMatch(players, scores, game.config, pressMatches));
        } else {
          results.push(calcLiveNassauStroke(players, scores));
        }
        break;
      case 'skins':
        results.push(calcLiveSkins(players, scores, game.config));
        break;
      case 'wolf':
        results.push(calcLiveWolf(players, scores, wolfHoles, game.config));
        break;
      case 'bingo-bango-bongo':
        results.push(calcLiveBBB(players, bbbHoles));
        break;
      case 'snake':
        results.push(calcLiveSnake(players, snakeHoles));
        break;
      case 'vegas': {
        const vegasCfg = game.config;
        const teamAPlayers = players.filter(p => vegasCfg.teamA.includes(p.id));
        const teamBPlayers = players.filter(p => vegasCfg.teamB.includes(p.id));
        const teamAName = teamAPlayers.map(p => p.name.split(' ')[0]).join('/');
        const teamBName = teamBPlayers.map(p => p.name.split(' ')[0]).join('/');
        results.push({
          mode: 'vegas',
          label: 'Vegas',
          lines: [
            { text: `${teamAName} vs ${teamBName}`, color: 'neutral' },
            { text: 'In progress', color: 'neutral' },
          ],
        });
        break;
      }
      case 'best-ball': {
        const bbCfg = game.config;
        const teamAPlayers = players.filter(p => bbCfg.teamA.includes(p.id));
        const teamBPlayers = players.filter(p => bbCfg.teamB.includes(p.id));
        const teamAName = teamAPlayers.map(p => p.name.split(' ')[0]).join('/');
        const teamBName = teamBPlayers.map(p => p.name.split(' ')[0]).join('/');

        // Live: calculate running best ball scores
        let runningA = 0; let runningB = 0; let holesA = 0; let holesB = 0;
        for (let h = 0; h < 18; h++) {
          const aS = teamAPlayers.map(p => scores[p.id]?.[h]).filter((s): s is number => s !== null && s !== undefined);
          const bS = teamBPlayers.map(p => scores[p.id]?.[h]).filter((s): s is number => s !== null && s !== undefined);
          if (aS.length === 0 || bS.length === 0) continue;
          const bestA = Math.min(...aS); const bestB = Math.min(...bS);
          runningA += bestA; runningB += bestB;
          if (bestA < bestB) holesA++; else if (bestB < bestA) holesB++;
        }

        const lines: LiveStatusLine[] = [];
        if (bbCfg.mode === 'stroke') {
          const diff = runningA - runningB;
          lines.push({ text: diff === 0 ? `${teamAName} tied ${teamBName}` : diff < 0 ? `${teamAName} −${Math.abs(diff)}` : `${teamBName} −${Math.abs(diff)}`, color: diff === 0 ? 'neutral' : diff < 0 ? 'green' : 'red' });
        } else {
          const diff = holesA - holesB;
          lines.push({ text: diff === 0 ? `All Square` : diff > 0 ? `${teamAName} +${diff} holes` : `${teamBName} +${Math.abs(diff)} holes`, color: diff === 0 ? 'neutral' : 'green' });
        }
        results.push({ mode: 'best-ball', label: 'Best Ball', lines });
        break;
      }
      case 'stableford':
        results.push(calcLiveStableford(players, scores, pars));
        break;
      case 'rabbit':
        results.push(calcLiveRabbit(players, scores));
        break;
      case 'dots':
        results.push(calcLiveDots(players, scores, pars, dotsHoles ?? [], game.config));
        break;
      case 'sixes':
        results.push(calcLiveSixes(players, scores));
        break;
      case 'nines':
        results.push(calcLiveNines(players, scores));
        break;
      case 'scotch':
        results.push(calcLiveScotch(players, scores, game.config));
        break;
      case 'ctp':
        results.push(calcLiveCtp(players, pars, ctpHoles ?? []));
        break;
      case 'aces-deuces':
        results.push(calcLiveAcesDeuces(players, scores, game.config));
        break;
    }
  }

  return results;
}
