# Snaps 🏌️

**The ultimate golf betting companion app.**

Track bets, settle scores, and play 22 different golf games with your friends — all in one beautifully designed iOS app.

![SwiftUI](https://img.shields.io/badge/SwiftUI-blue?logo=swift&logoColor=white)
![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

### 🎮 22 Game Modes
- **Tax Man** — Set your target, beat it to win
- **Nassau** — Front 9, Back 9, Overall (stroke or match play)
- **Skins** — Win holes outright, carryovers stack
- **Wolf** — Pick partners on the fly, go solo for big money
- **Vegas** — 2v2 concatenated scores
- **Best Ball** — Team lowest score wins
- **Stableford** — Points-based scoring
- **And 15 more...** including Rabbit, Dots/Junk, Banker, Hammer, and more

### 📊 Stats & Tracking
- Per-hole score entry with +/- buttons
- Fairway direction tracking (hit/left/right)
- Green in regulation tracking (hit/short/long/left/right)
- Putts per hole with 3-putt highlighting
- Live standings as you play

### 🏆 Pro Data
- Live PGA Tour leaderboards (ESPN)
- World Rankings (OWGR)

### 🌙 Light & Dark Mode
Full support for both themes — your eyes will thank you for those early morning rounds.

### 💸 Payment Integration
- Venmo deep links
- Cash App deep links
- Settle up instantly after the round

---

## Screenshots

*Coming soon*

---

## Tech Stack

- **SwiftUI** — Native iOS UI
- **SwiftData** — Local persistence
- **Supabase** — Cloud backend & auth
- **ESPN API** — Live leaderboard data

---

## Requirements

- iOS 17.0+
- Xcode 15.0+

---

## Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/bobbyfeeno/snaps.git
   cd snaps/ios-native
   ```

2. Open in Xcode:
   ```bash
   open SnapsNative.xcodeproj
   ```

3. Build and run on simulator or device

---

## Project Structure

```
ios-native/
├── Sources/SnapsNative/
│   ├── Models/          # Game logic, data models
│   ├── Views/           # SwiftUI views
│   ├── Services/        # Supabase, repositories
│   └── Assets.xcassets/ # Images, colors
├── SnapsNative.xcodeproj
└── supabase_schema.sql  # Database schema
```

---

## Game Modes

| Game | Players | Description |
|------|---------|-------------|
| Keep Score | 1-8 | Standard scorecard |
| Head to Head | 2+ | Match or stroke play |
| Tax Man | 2-8 | Beat your target number |
| Nassau | 2-4 | Three bets in one |
| Skins | 2-8 | Win holes outright |
| Wolf | 4 | Pick partners each hole |
| Vegas | 4 | 2v2 combined scores |
| Best Ball | 4 | Team low ball |
| Stableford | 2-8 | Points per hole |
| Rabbit | 2-8 | Hold the rabbit to win |
| Dots/Junk | 2-8 | Side bets for great shots |
| Sixes | 4 | Rotating partners |
| Nines | 3 | 9 points per hole |
| Scotch | 4 | 2v2 low ball/total |
| Banker | 3-4 | Play against the banker |
| Hammer | 2-4 | Double the bet mid-hole |
| *...and more* | | |

---

## Contributing

This is a personal project, but suggestions welcome! Open an issue or reach out.

---

## Author

**Bobby Feeno**  
[@bobbyfeeno](https://github.com/bobbyfeeno)

---

## License

MIT License — see [LICENSE](LICENSE) for details.
