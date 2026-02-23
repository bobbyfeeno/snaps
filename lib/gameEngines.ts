import {
  BBBHoleState,
  BingoBangoBongoConfig,
  GameConfig,
  GameResult,
  GameSetup,
  MultiGameResults,
  NassauConfig,
  Payout,
  Player,
  SkinsConfig,
  SnakeConfig,
  SnakeHoleState,
  TaxManConfig,
  WolfConfig,
  WolfHoleState,
} from '../types';

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

  const legs: { name: string; start: number; end: number }[] = [
    { name: 'Front 9', start: 0, end: 9 },
    { name: 'Back 9', start: 9, end: 18 },
    { name: 'Full 18', start: 0, end: 18 },
  ];

  for (const leg of legs) {
    // Calculate totals for each player for this leg
    const totals: { player: Player; total: number }[] = [];
    
    for (const player of players) {
      const total = sumScores(scores[player.id], leg.start, leg.end);
      if (total !== null) {
        totals.push({ player, total });
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

function calcNassauMatch(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: NassauConfig
): { payouts: Payout[]; net: Record<string, number> } {
  const payouts: Payout[] = [];
  const net = initNet(players);

  const legs: { name: string; start: number; end: number }[] = [
    { name: 'Front 9', start: 0, end: 9 },
    { name: 'Back 9', start: 9, end: 18 },
    { name: 'Full 18', start: 0, end: 18 },
  ];

  for (const leg of legs) {
    // Count holes won per player for this leg
    const holesWon: Record<string, number> = {};
    for (const p of players) {
      holesWon[p.id] = 0;
    }

    for (let hole = leg.start; hole < leg.end; hole++) {
      // Get scores for this hole (only players with non-null scores)
      const holeScores: { player: Player; score: number }[] = [];
      
      for (const player of players) {
        const score = scores[player.id][hole];
        if (score !== null) {
          holeScores.push({ player, score });
        }
      }

      if (holeScores.length < 2) continue; // Need at least 2 players with scores

      // Find lowest score for this hole
      const minScore = Math.min(...holeScores.map(h => h.score));
      const holeWinners = holeScores.filter(h => h.score === minScore);

      // Single winner takes the hole; ties = halved (no hole winner)
      if (holeWinners.length === 1) {
        holesWon[holeWinners[0].player.id]++;
      }
    }

    // Find who won the most holes in this leg
    const participatingPlayers = players.filter(p => {
      // Player participated if they have at least one non-null score in this leg
      for (let h = leg.start; h < leg.end; h++) {
        if (scores[p.id][h] !== null) return true;
      }
      return false;
    });

    if (participatingPlayers.length < 2) continue;

    const maxHolesWon = Math.max(...participatingPlayers.map(p => holesWon[p.id]));
    if (maxHolesWon === 0) continue; // No holes won = no payout

    const legWinners = participatingPlayers.filter(p => holesWon[p.id] === maxHolesWon);

    // If tied on holes won = push (no payout for this leg)
    if (legWinners.length > 1) continue;

    const winner = legWinners[0];

    // Winner receives betAmount from each other participating player
    for (const other of participatingPlayers) {
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

  return { payouts, net };
}

export function calcNassau(
  players: Player[],
  scores: Record<string, (number | null)[]>,
  config: NassauConfig
): GameResult {
  // Default to stroke play for backwards compatibility
  const mode = config.mode ?? 'stroke';
  
  const { payouts, net } = mode === 'match'
    ? calcNassauMatch(players, scores, config)
    : calcNassauStroke(players, scores, config);

  return {
    mode: 'nassau',
    label: mode === 'match' ? 'Nassau (Match)' : 'Nassau',
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

// ─── Master: Calculate all active games ─────────────────────────────────────

export interface GameExtras {
  wolf?: (WolfHoleState | null)[];
  bbb?: (BBBHoleState | null)[];
  snake?: (SnakeHoleState | null)[];
}

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
        result = calcNassau(players, scores, game.config);
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
