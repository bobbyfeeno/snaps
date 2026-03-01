# Snaps ⛳

**Native SwiftUI golf betting scorecard app for iOS**

Track bets, score every hole, calculate payouts, and settle up instantly after the round. Supports 10 simultaneous game engines with live money tracking per player.

---

## Getting Started

1. Open **`Snaps.xcodeproj`** in Xcode 16+
2. Select any iOS 17+ simulator or physical device
3. Hit **Run** — no backend required (runs fully offline via `MockRepository`)

To enable cloud sync and auth, set your Supabase credentials in `Sources/Snaps/Services/SupabaseRepository.swift` and swap `MockRepository` for `SupabaseRepository` in `AppState.swift`.

---

## Features

### 🎮 10 Game Engines
All engines run simultaneously, calculating payouts hole-by-hole:

| Game | Description |
|------|-------------|
| **TaxMan** | Handicap-adjusted stroke play — low net wins from all others |
| **Nassau** | Front 9 / Back 9 / Total — optional auto-press |
| **Wolf** | Rotating wolf picks a partner each hole; lone wolf pays double |
| **Bingo Bango Bongo** | 3 pts/hole — first on green, closest to pin, first to hole out |
| **Snake** | 3-putt penalty pool — last 3-putter holds the snake |
| **Vegas** | Team game combining scores into 2-digit numbers; birdie flips |
| **CTP** | Closest to pin skins on par 3s |
| **Trouble** | Penalty pool — water, OB, 3-putt, sand, whiff, etc. |
| **Arnies** | Bonus for making par without touching the fairway |
| **Banker** | Rotating banker sets the bet per hole; others accept or fold |

### ⛳ Round Flow
- Multi-step setup wizard — players → games → Vegas teams → bet amounts
- Hole-by-hole scorecard with swipe navigation and haptic feedback
- Per-hole tracking panels for Wolf partner, BBB points, Snake 3-putts, Banker, CTP, Trouble, Arnies
- **Live running score badge** (score relative to par) per player
- **Live Round tab** — appears in tab bar when a round is active, auto-switches on start
- Full 18-hole scorecard grid — eagle (gold circle), birdie (red circle), bogey (blue square), double+ (red square)

### 📊 Stats & Tracking
- FIR / GIR / putts tracked per hole for logged-in user
- Interactive fairway and green direction cards
- Season leaderboard and round history
- YouView — merged profile + career stats dashboard
- PGA Tour leaderboard (TourView)

### 💸 Settlement
- Animated per-game payout reveal with confetti
- Venmo deep link — pre-filled with amount + note
- CashApp deep link — pre-filled with amount

### 🔐 Auth & Cloud
- Supabase authentication (email/password)
- Cloud profile, round history, and player sync
- Protocol-based repo pattern — swap `MockRepository` ↔ `SupabaseRepository` with no UI changes

---

## Project Structure

```
snaps/
├── Snaps.xcodeproj
├── Sources/
│   └── Snaps/
│       ├── Models/
│       │   ├── AppModels.swift       # Player, Round, Course types
│       │   ├── GameModels.swift      # GameMode, PlayerSnapshot, config types
│       │   └── GameEngine.swift      # All 10 game engines (pure functions)
│       ├── Services/
│       │   ├── AppState.swift        # ObservableObject global state
│       │   ├── SnapsRepository.swift # Protocol definition
│       │   ├── MockRepository.swift  # Offline mock — no backend needed
│       │   └── SupabaseRepository.swift # Supabase cloud backend
│       └── Views/
│           ├── DesignSystem.swift    # Colors, fonts, shared components
│           ├── HomeView.swift
│           ├── SetupView.swift
│           ├── ScoreCardView.swift
│           ├── HoleTrackerView.swift
│           ├── ScorecardGridView.swift
│           ├── FairwaysHitCard.swift
│           ├── ResultsView.swift
│           ├── HistoryView.swift
│           ├── RoundDetailView.swift
│           ├── LeaderboardView.swift
│           ├── PlayersView.swift
│           ├── YouView.swift
│           ├── StatsView.swift
│           ├── RulesView.swift
│           ├── TourView.swift
│           ├── LobbyView.swift
│           ├── LoginView.swift
│           └── VoiceScoreEntry.swift
├── supabase_schema.sql    # Run once in Supabase SQL editor
└── project.yml            # XcodeGen spec
```

---

## Roadmap

- [ ] Course editor — set par + course name per hole before round
- [ ] Save completed round to history after results screen
- [ ] App icon + launch screen
- [ ] Onboarding flow
- [ ] SwiftData offline persistence with Supabase sync
- [ ] Live multiplayer via Supabase Realtime (join code flow)
- [ ] Apple Watch companion
- [ ] GHIN handicap sync
- [ ] Apple Pay settlement
