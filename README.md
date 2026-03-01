# Snaps ⛳

**Golf betting scorecard app — native SwiftUI iOS**

Track bets, calculate payouts, and settle up after the round. Supports 10 game engines simultaneously with live money tracking per hole.

---

## Getting Started

1. Open `SnapsNative.xcodeproj` in **Xcode 16+**
2. Select any **iOS 17+ simulator** (or physical device)
3. Hit **Run** — no API keys or backend required (runs fully offline with mock data)

For cloud features (auth, multiplayer), configure Supabase credentials in `SupabaseRepository.swift`.

---

## Game Engines

All 10 engines run simultaneously and produce per-hole payouts:

| Game | Description |
|------|-------------|
| **TaxMan** | Handicap-adjusted stroke play — low net wins from all others |
| **Nassau** | Front 9 / Back 9 / Total — optional auto-press |
| **Wolf** | Rotating wolf picks partner each hole; lone wolf pays double |
| **Bingo Bango Bongo** | 3 pts/hole — first on green, closest to pin, first to hole out |
| **Snake** | 3-putt penalty pool — last 3-putter holds the snake |
| **Vegas** | Team game combining scores into 2-digit numbers; birdie flips |
| **CTP** | Closest to pin skins on par 3s |
| **Trouble** | Penalty pool — water, OB, 3-putt, sand, whiff, etc. |
| **Arnies** | Bonus for making par without touching the fairway |
| **Banker** | Rotating banker sets the bet per hole; others accept or fold |

---

## Architecture

```
Sources/SnapsNative/
├── Models/
│   ├── AppModels.swift       # Player, Round, Course data models
│   ├── GameModels.swift      # GameMode enum, PlayerSnapshot, config types
│   └── GameEngine.swift      # All 10 game engines (pure functions)
├── Services/
│   ├── AppState.swift        # ObservableObject global state
│   ├── SnapsRepository.swift # Protocol: load/save players, rounds
│   ├── MockRepository.swift  # In-memory mock — no backend needed
│   └── SupabaseRepository.swift # Supabase cloud backend
└── Views/
    ├── DesignSystem.swift    # Colors, typography, reusable components
    ├── HomeView.swift
    ├── SetupView.swift       # Multi-step: players → games → teams → bets
    ├── ScoreCardView.swift   # Hole-by-hole with per-game tracking panels
    ├── HoleTrackerView.swift # Wolf partner, BBB, Snake, Banker, CTP, etc.
    ├── ScorecardGridView.swift # 18-hole grid with color-coded scores
    ├── ResultsView.swift     # Animated payouts + Venmo/CashApp deep links
    ├── HistoryView.swift     # Round history + season leaderboard
    ├── LeaderboardView.swift
    ├── PlayersView.swift     # Player management
    ├── YouView.swift         # Profile + stats dashboard
    ├── StatsView.swift
    ├── RulesView.swift       # Game rules reference
    ├── TourView.swift        # PGA Tour leaderboard
    ├── LoginView.swift       # Supabase auth
    ├── LobbyView.swift       # Multiplayer join code
    └── VoiceScoreEntry.swift # Speech-to-text score input
```

**Repository pattern:** swap `MockRepository` for `SupabaseRepository` with no UI changes.

---

## Roadmap

- [ ] Course editor (set par per hole + course name before round)
- [ ] Save round to history after results screen
- [ ] App icon + launch screen
- [ ] Onboarding flow
- [ ] SwiftData offline persistence with Supabase sync
- [ ] Live multiplayer via Supabase Realtime
- [ ] Apple Watch companion
- [ ] GHIN handicap sync
- [ ] Apple Pay settlement
