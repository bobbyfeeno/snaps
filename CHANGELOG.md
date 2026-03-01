# SwiftUI Native iOS Rewrite — Changelog

> **Branch:** `feature/swiftui-native-rewrite`  
> **Author:** qchay  
> **Base:** `bobbyfeeno/snaps` main (React Native / Expo)

---

## Overview

This branch introduces a complete **native SwiftUI rewrite** of the Snaps golf betting app, living alongside the existing React Native app in the `ios-native/` directory. The goal is a fully offline-capable, performant iOS client that can optionally be connected to the existing Supabase backend.

---

## New Features

### 🎮 10 Game Engines (Pure Swift)

All game engines are implemented in `Sources/SnapsNative/Models/GameEngine.swift` with deterministic, testable pure functions:

| Engine | Description |
|--------|-------------|
| **TaxMan** | Handicap-adjusted stroke play with USGA hole difficulty rankings |
| **Nassau** | Front 9 / Back 9 / Total with optional auto-press |
| **Wolf** | Rotating wolf picks partner per hole; lone wolf doubles; handles holes 17/18 (leader gets wolf) |
| **Bingo Bango Bongo** | 3 points per hole: first on green, closest to pin, first to hole out |
| **Snake** | 3-putt penalty pool — last player to 3-putt holds the snake |
| **Vegas** | Team game combining scores into 2-digit numbers; flip rule on birdie |
| **CTP (Closest to Pin)** | Par-3 skins per hole |
| **Trouble** | Penalty pool for water, OB, 3-putt, sand, whiff, etc. |
| **Arnies** | Bonus for making par without touching the fairway (par-3 excluded) |
| **Banker** | Rotating banker sets the bet per hole; others accept or fold |

All engines output structured `Payout` and `GameResult` types and can be combined via `calcAllGames()`.

---

### 📋 Setup Wizard

Multi-step flow (`SetupView.swift`):
1. **Player selection** — pick from saved players or add new
2. **Game mode selection** — toggle any combination of the 10 engines
3. **Vegas team assignment** — drag-assign players to Team A/B
4. Configurable bet amounts per game

---

### ⛳ Hole-by-Hole Scorecard

`ScoreCardView.swift` + `HoleTrackerView.swift`:
- Swipeable hole navigation
- +/− score steppers with haptic feedback
- Per-hole manual tracking panels:
  - **Wolf:** pick partner or go lone wolf
  - **BBB:** assign Bingo / Bango / Bongo
  - **Snake:** mark 3-putters
  - **Banker:** assign banker per hole
  - **CTP:** mark closest to pin
  - **Trouble/Arnies/Dots:** tap to assign
- Live running money ticker per player

---

### 📊 Full 18-Hole Scorecard Grid

`ScorecardGridView.swift`:
- Compact grid showing all players × all holes
- Color-coded: eagle (gold circle), birdie (red circle), par (plain), bogey (blue square), double+ (red square)
- Front/back/total summaries

---

### 🏆 Results Screen

`ResultsView.swift`:
- Animated per-game payout reveal
- Confetti on winner
- Combined net leaderboard
- **Venmo deep link** — tap to open Venmo pre-filled with amount + note
- **CashApp deep link** — tap to open CashApp pre-filled

---

### 📜 History & Season Leaderboard

`HistoryView.swift`:
- Round-by-round history list
- 4 stat views: earnings, wins, avg score, games played
- Season leaderboard with net earnings

---

### 👤 Player Management & Profile

`PlayersView.swift` / `ProfileView.swift`:
- Add/edit players with name, handicap (TaxMan strokes), Venmo handle, CashApp handle
- Profile dashboard: career stats, recent rounds

---

### 🎙️ Voice Score Entry

`VoiceScoreEntry.swift`:
- Speech-to-text score input using AVFoundation + Speech framework
- Understands: "birdie", "eagle", "bogey", "double", "par", plain numbers
- Hands-free scoring during a round

---

### 🏠 Lobby / Multiplayer Stub

`LobbyView.swift`:
- Generate 6-character join code
- Invite flow UI (mock — ready for Supabase realtime)
- No backend required to run the app locally

---

## Architecture

```
ios-native/
├── Sources/SnapsNative/
│   ├── SnapsApp.swift              # App entry + TabView
│   ├── Models/
│   │   ├── AppModels.swift         # Player, Round, Course data models
│   │   ├── GameModels.swift        # GameMode enum, PlayerSnapshot, config types
│   │   └── GameEngine.swift        # All 10 game engines (pure functions)
│   ├── Services/
│   │   ├── AppState.swift          # ObservableObject global state
│   │   ├── SnapsRepository.swift   # Protocol: load/save players, rounds
│   │   └── MockRepository.swift    # In-memory mock (no Supabase needed)
│   └── Views/
│       ├── HomeView.swift
│       ├── SetupView.swift
│       ├── ScoreCardView.swift
│       ├── HoleTrackerView.swift
│       ├── ScorecardGridView.swift
│       ├── ResultsView.swift
│       ├── HistoryView.swift
│       ├── LeaderboardView.swift
│       ├── LobbyView.swift
│       ├── PlayersView.swift
│       ├── ProfileView.swift
│       └── VoiceScoreEntry.swift
├── SnapsNative.xcodeproj
├── project.yml                     # XcodeGen spec
└── supabase_schema.sql             # DB schema (ready for Supabase integration)
```

---

## What's Not Done Yet (Roadmap)

- [ ] **Course editor** — set par per hole + course name before round
- [ ] **Save round to history** — persist completed rounds after results screen
- [ ] **App icon + Launch screen**
- [ ] **Onboarding flow** — first-time user experience
- [ ] **Supabase integration** — swap `MockRepository` for real Supabase client
- [ ] **Apple Sign In** — real auth
- [ ] **Live multiplayer** — real join codes via Supabase Realtime
- [ ] **SwiftData persistence** — offline-first with cloud sync
- [ ] **Apple Watch companion**
- [ ] **GHIN handicap sync**

---

## How to Run

1. Open `ios-native/SnapsNative.xcodeproj` in Xcode 16+
2. Select **iPhone 16e** simulator (or any iOS 17+ device)
3. Hit **Run** — no API keys or backend needed (uses mock data)

---

## Relation to React Native App

This is an **additive parallel implementation** — it does not modify any existing React Native / Expo code. The same game logic that exists in `lib/gameEngines.ts` has been re-implemented in Swift. The Supabase schema (`supabase_schema.sql`) is compatible with the existing backend.
