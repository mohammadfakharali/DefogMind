# DefogMind: Screen Time & Focus

DefogMind is a privacy-first, on-device digital habit, screen-time blocker, and cognitive wellbeing utility for Android built with Flutter and native Kotlin.

---

## 🌟 Key Features

### 1. Progressive Brain Fog Fatigue Engine
Unlike simplistic linear timers, DefogMind models cognitive screen fatigue based on an accelerating biological curve:
- **Fresh Mind (0 – 45 min)**: `+1%` fog per `1.5 minutes` (Mint `#10B981`)
- **Tired Mind (45 – 70 min)**: `+1%` fog per `1.25 minutes` (Amber `#F59E0B`)
- **Heavy Mind (70 – 100 min)**: `+1%` fog per `1.0 minute` (Orange `#FB923C`)
- **Overloaded Mind (100 – 120 min+)**: `+1%` fog per `1.0 minute` (Glitch Red `#EF4444`)
- **Biological Break Recovery**: Decreases at `-1%` every `3 minutes` spent outside monitored apps (5 hours of night sleep = 100% full recovery).
- **Midnight Persistence**: Brain fog persists across midnight and heals organically through actual sleep/rest off the phone (only daily quota resets at 12:00 AM).
- **Offline Rest Recovery**: Elapsed rest/sleep time while the phone was turned off is credited immediately upon boot.

### 2. Dual Focus Modes
- **Awareness Mode**: Non-blocking mindfulness mode. Floating HUD gently peeks for 10 seconds on app open, at every 5% fog milestone, and whenever mind status transitions between tiers, then fades away to keep the screen clean.
- **Limit Mode**: Enforces a strict daily quota on selected apps. Peeks for 10 seconds on app open and every 5 minutes (5m, 10m, 15m...). Stays continuously visible in the final 5 minutes until the blocking shield locks the app.

### 3. Extra Unlock Passes & Mental Math Gate
- Daily quota includes emergency Extra Unlock Passes.
- Claiming extra time or modifying app limits requires solving a quick mental math focus challenge to prevent mindless scrolling.

### 4. Kids Mode Sandbox (Child Hand-Off)
- Allow-list-only sandbox for handing the phone to children.
- Dedicated timer with Smart Countdown: 10-second peeks on app open and at 5-minute intervals, followed by a continuous warning in the final 5 minutes.
- Secured with a 4-digit Parent PIN and security question recovery.
- Complete adult data isolation and zero advertising in Kids Mode.

### 5. 2×2 Home Screen Brain Clarity Widget
- Native Android 2×2 widget displaying real-time brain clarity, fatigue tier mascot, and screen-time quota.
- Tapping the widget opens DefogMind directly.

---

## 🔒 Privacy & Safety Guarantee
- **100% On-Device Processing**: App usage data never leaves the device.
- **No Accessibility Service Abuse**: Strict compliance with Google Play Developer policies using `UsageStatsManager`.
- **Zero Ads on Overlays & Kids Mode**: Zero banners or interstitials on system lock screens or while Kids Mode is active.

---

## 🛠️ Tech Stack & Architecture
- **Framework**: Flutter & Dart (Null-Safe)
- **Native Android Core**: Kotlin, `FocusMonitorService` (`specialUse` Foreground Service), `AppWidgetProvider`, `WindowManager` Overlays
- **Architecture Reference**: See [`documentation/FOGOFF_DOCUMENTATION.md`](documentation/FOGOFF_DOCUMENTATION.md) for complete technical and policy specifications.
