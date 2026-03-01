# Snaps ⛳

**Golf betting scorecard app — native SwiftUI iOS**

Track bets, calculate payouts, and settle up after the round. Supports 10 game engines simultaneously with live money tracking per hole.

---

## Getting Started

1. Open `ios-native/SnapsNative.xcodeproj` in **Xcode 16+**
2. Select any **iOS 17+ simulator** (or physical device)
3. Hit **Run** — no API keys required (runs offline with mock data)

For cloud features, configure Supabase credentials in `ios-native/Sources/SnapsNative/Services/SupabaseRepository.swift`.

---

## Game Engines

| Game | Description |
|------|-------------|
| **TaxMan** | Handicap-adjusted stroke play |
| **Nassau** | Front 9 / Back 9 / Total with optional press |
| **Wolf** | Rotating wolf picks partner each hole |
| **Bingo Bango Bongo** | 3 pts/hole — first on green, closest, first to hole out |
| **Snake** | 3-putt penalty pool |
| **Vegas** | Team game with birdie flip rule |
| **CTP** | Closest to pin skins on par 3s |
| **Trouble** | Penalty pool — water, OB, sand, whiff, etc. |
| **Arnies** | Par without touching the fairway |
| **Banker** | Rotating banker sets bet per hole |

---

## Architecture

```
ios-native/Sources/SnapsNative/
├── Models/         # GameEngine, AppModels, GameModels
├── Services/       # AppState, MockRepository, SupabaseRepository
└── Views/          # All UI (DesignSystem, HomeView, ScoreCardView, etc.)
```

Swap `MockRepository` for `SupabaseRepository` in `AppState.swift` to go live.
