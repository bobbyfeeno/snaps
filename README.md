# Snaps ⛳

**Native SwiftUI golf betting scorecard app for iOS**

Track bets, score every hole, calculate payouts, and settle up instantly after the round. Supports 22 game modes simultaneously with live money tracking per player.

---

## Getting Started

1. Open **`Snaps.xcodeproj`** in Xcode 16+
2. Select any iOS 17+ simulator or physical device
3. Hit **Run** — no backend required (runs fully offline via `MockRepository`)

To enable cloud sync and auth, set your Supabase credentials in `Sources/Snaps/Services/SupabaseRepository.swift` and swap `MockRepository` for `SupabaseRepository` in `AppState.swift`.

---

## Features

### 🎮 22 Game Modes

| Game | Description |
|------|-------------|
| **Keep Score** | Simple stroke play scorecard — no betting |
| **Head to Head** | Match play or stroke play between any two players; supports handicaps |
| **Tax Man** | Handicap-adjusted stroke play — low net wins from all others |
| **Nassau** | Front 9 / Back 9 / Total — optional auto-press |
| **Skins** | Hole-by-hole winner takes the skin; ties carry over |
| **Wolf** | Rotating wolf picks a partner each hole; lone wolf pays double |
| **Bingo Bango Bongo** | 3 pts/hole — first on green, closest to pin, first to hole out |
| **Snake** | 3-putt penalty pool — last 3-putter holds the snake |
| **Vegas** | Team game combining scores into 2-digit numbers; birdie flips |
| **Best Ball** | 2v2 team format — best net score per team per hole |
| **Stableford** | Points system: eagle=5, birdie=4, par=2, bogey=1 |
| **Rabbit** | Hole winner "holds the rabbit" until someone else birdies/wins |
| **Dots / Junk** | Bonus points for birdies, sandies, greenies, and other highlights |
| **Sixes** | Rotating 2v2 partners every 6 holes |
| **Nines** | 9 points distributed per hole based on finishing position |
| **Scotch** | Alternating shot team format |
| **Closest to Pin (CTP)** | Skins for closest to pin on par 3s |
| **Aces & Deuces** | Hole-in-one pool; low score wins from everyone else |
| **Quota** | Points vs. personal quota (handicap-based) |
| **Trouble** | Penalty pool — water, OB, 3-putt, sand trap, whiff, etc. |
| **Arnies** | Bonus for making par without touching the fairway |
| **Banker** | Rotating banker sets the bet per hole; others accept or fold |

### ⛳ Round Flow
- Multi-step setup wizard — players → games → Vegas/Best Ball teams → bet amounts
- Hole-by-hole scorecard with swipe navigation and haptic feedback
- Per-hole tracking panels for Wolf partner, BBB points, Snake, Banker, CTP, Trouble, Arnies, Dots
- **Live running score badge** (relative to par) per player on scorecard
- **Live Round tab** — appears in tab bar when a round is active, auto-switches on start
- **Fullscreen scorecard** — locks in after round starts
- Full 18-hole grid — eagle (gold circle), birdie (red circle), bogey (blue square), double+ (red square)

### 📊 Stats & Tracking
- FIR / GIR / putts tracked per hole for logged-in user
- Interactive fairway hit direction and green-in-regulation cards
- Season leaderboard and round history
- **YouView** — merged profile + career stats dashboard
- **StatsView** — detailed per-round stat breakdowns
- **TourView** — live PGA Tour leaderboard

### 💸 Settlement
- Animated per-game payout reveal with confetti on round completion
- **Venmo deep link** — pre-filled with amount + note
- **CashApp deep link** — pre-filled with amount

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
│       │   ├── AppModels.swift         # Player, Round, Course types
│       │   ├── GameModels.swift        # GameMode enum (22 modes), PlayerSnapshot, config types
│       │   └── GameEngine.swift        # All 22 game engine functions (pure Swift)
│       ├── Services/
│       │   ├── AppState.swift          # ObservableObject global state
│       │   ├── SnapsRepository.swift   # Protocol definition
│       │   ├── MockRepository.swift    # Offline mock — no backend needed
│       │   └── SupabaseRepository.swift # Supabase cloud backend
│       └── Views/
│           ├── DesignSystem.swift      # Colors, fonts, shared components
│           ├── HomeView.swift
│           ├── SetupView.swift         # Multi-step game setup wizard
│           ├── ScoreCardView.swift     # Hole-by-hole scoring + live badges
│           ├── HoleTrackerView.swift   # Per-hole game tracking panels
│           ├── ScorecardGridView.swift # 18-hole color-coded grid
│           ├── FairwaysHitCard.swift   # FIR/GIR direction tracker
│           ├── ResultsView.swift       # Payouts + Venmo/CashApp deep links
│           ├── HistoryView.swift       # Round history list
│           ├── RoundDetailView.swift   # Per-round breakdown
│           ├── LeaderboardView.swift   # Season leaderboard
│           ├── PlayersView.swift       # Player management
│           ├── YouView.swift           # Profile + career stats
│           ├── StatsView.swift         # Detailed stat breakdowns
│           ├── RulesView.swift         # In-app game rules reference
│           ├── TourView.swift          # Live PGA Tour leaderboard
│           ├── LobbyView.swift         # Multiplayer join code
│           ├── LoginView.swift         # Supabase auth
│           └── VoiceScoreEntry.swift   # Speech-to-text score input
├── supabase_schema.sql   # Run once in Supabase SQL editor to set up tables
└── project.yml           # XcodeGen spec
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
