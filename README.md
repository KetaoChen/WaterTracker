# 💧 WaterTracker

Simple water intake tracker for iOS & Apple Watch with Shortcuts support.

## Features

- 📱 **iOS App** - Track daily water intake with quick-add buttons
- ⌚ **Apple Watch** - Log water directly from your wrist
- 🎯 **Daily Goal** - Visual progress ring (default 2L)
- 🔗 **Shortcuts** - "Log Water" and "Get Water Intake" intents
- 🗣️ **Siri** - "Hey Siri, 记录喝水"
- 📊 **Widgets** - Home screen & Watch complications

## Tech Stack

- SwiftUI (iOS 17+, watchOS 10+)
- App Intents (Shortcuts & Siri)
- WidgetKit
- SwiftData (local persistence)
- HealthKit (optional sync)

## Project Structure

```
WaterTracker/
├── WaterTracker/           # iOS App
├── WaterTrackerWatch/      # watchOS App
├── WaterTrackerWidgets/    # Widgets
├── Shared/                 # Shared code
│   ├── Models/
│   ├── Intents/
│   └── Managers/
└── WaterTracker.xcodeproj
```

## Getting Started

1. Open `WaterTracker.xcodeproj` in Xcode
2. Select your team for signing
3. Build & run on device/simulator

## License

MIT
