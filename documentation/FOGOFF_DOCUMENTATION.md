# DefogMind: Screen Time & Focus — Master Architecture, Features & Compliance Reference

> **AI Assistant Onboarding Note**: This file is the complete, up-to-date architectural and policy source of truth for **DefogMind**. Read this file first in any new session to understand all features, file paths, native bridges, and strict Google Play / AdMob guardrails.

- **Workspace Root:** `E:\Dev\Apps\DefogMind`
- **App Name (Launcher & Splash):** `DefogMind` (styled as `Defog` in White + `Mind` in Mint Green `#10B981`)
- **Official Google Play Store Title (30/30 chars):** `DefogMind: Screen Time & Focus`
- **Android Package ID (`applicationId` & `namespace`):** `com.defogmind.app`
- **MethodChannel Name:** `com.defogmind/platform`
- **Native SharedPreferences:** `DefogMindMonitorPrefs` & `FlutterSharedPreferences`
- **Version:** `1.0.0+1` (Production-Ready)
- **Target Platform:** Android (Minimum SDK 26, Target SDK 35, Compile SDK 36, Java 17)
- **Flutter SDK Path:** `C:\src\flutter\bin\flutter.bat`
- **Java Home (Android Studio JBR):** `C:\Program Files\Android\Android Studio\jbr`

---

## 1. Project File Map (`E:\Dev\Apps\DefogMind`)

### Native Android (`android/app/src/main/kotlin/com/defogmind/app/`)
- [`MainActivity.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/MainActivity.kt): Hosts the `com.defogmind/platform` MethodChannel. Runs heavy `UsageStatsManager` and `PackageManager.getInstalledApplications` queries on a background single-thread executor (`bgExecutor`) so the main UI thread never skips frames. Houses `isPinWidgetSupported`, `requestPinWidget` (with deduplication protection), and `isWidgetAdded` platform hooks.
- [`FocusMonitorService.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/FocusMonitorService.kt): High-performance background `Service` (`foregroundServiceType="specialUse"`). Runs its 1-second foreground check loop on a dedicated background `HandlerThread("DefogMindMonitorBg")` and posts UI overlay updates to `mainHandler`. Implements the **Progressive Fatigue Engine**, organic break/offline rest recovery, midnight brain fog retention, smart floating pill peek logic (Limit Mode, Awareness Mode, and Kids Mode), Dual-Clock Extra Unlock countdown, and the Kids Mode sandbox.
- [`DefogMindWidgetProvider.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/DefogMindWidgetProvider.kt) & [`DefogMindWidgetUpdater.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/DefogMindWidgetUpdater.kt): Native Android 2×2 Home Screen Brain Clarity Widget. Features live brain character tiers, battery-efficient on-demand updates, launch-on-tap, and target 2×2 grid dimensions (`minWidth="140dp"` / `minHeight="140dp"` with `targetCellWidth="2"` / `targetCellHeight="2"`).
- [`OverlayActivity.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/OverlayActivity.kt): Full-screen native blocker shield (`#0B0F17`) with compact density-aware (`dp()`) buttons. Renders both the **Adult Focus Shield** (`DAILY LIMIT REACHED` + 10-second breathing gate) and the **Kids Mode Shield** (`🔒 LOCKED IN KIDS MODE` / `⏰ KIDS TIME FINISHED`).
- [`PassStorage.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/PassStorage.kt): Unified cross-platform storage bridge reading/writing `FlutterSharedPreferences` (`flutter.free_passes_remaining`, `flutter.bonus_passes_earned`, `flutter.last_pass_reset_day`, `flutter.oxygen_pass_duration_seconds`).
- [`BootReceiver.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/BootReceiver.kt): Automatically restarts `FocusMonitorService` on `BOOT_COMPLETED`.

### Flutter UI & Services (`lib/`)
- [`lib/main.dart`](file:///E:/Dev/Apps/DefogMind/lib/main.dart): `DefogMindRootApp` entry point with fast permission/onboarding check (`1000ms` timeout, zero artificial delay) and static `_BrandedSplashScreen` (`assets/images/app_logo.png` + `DefogMind` title).
- [`lib/presentation/screens/onboarding_disclosure_screen.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/onboarding_disclosure_screen.dart):
  - **Step 1 of 3 (Focus Style & Limits)**: Both focus modes start unselected (`_selectedMode = null`) with high-contrast, prominent cards so both choices are clear. If `Awareness Mode` (`_selectedMode = 0`) is selected, no sub-settings are displayed and the CTA button enables immediately (`Next: Select Apps to Track`). If `Limit Mode` (`_selectedMode = 1`) is selected, its two settings expand with a **circulating comet moving border effect** (`_MovingCometBorderCard`).
  - **Step 2 of 3 (Select Apps to Track)**: Navigates to `AppSelectionScreen(isOnboarding: true)`. Automatically detects and pre-selects known social apps **only if they are actually installed on the device** and pins them to the top. Bottom CTA button (`Next: Privacy & Permissions`) saves the package list and returns to Step 3.
  - **Step 3 of 3 (Privacy & Permissions)**: Top `100% On-Device Privacy Guarantee` banner positioned directly above permission cards. Cleanly organized into **REQUIRED** and **RECOMMENDED** sections with individual interactive guide sheets for Usage Access and Display Over Other Apps. Once required permissions are granted, smoothly transitions directly into `HomeDashboard` with zero modal interruption.
- [`lib/presentation/screens/home_dashboard.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/home_dashboard.dart):
  - **Adult Dashboard**: AppBar shows compact `DefogMind` title (`🧸 DefogMind Kids Mode` during Kids Mode). Mode switcher (`Awareness Mode` vs `Limit Mode`), `BrainFogVisualizer` card with `Adult Social Time`, tappable `Daily Target ✎` shortcut (opens `SettingsScreen`), `Adult: Xm • 🧸 Kids: Ym` split badge, and `Daily Limit Used` progress bar. When My App Tracking is paused (`adult_tracking_enabled == false`), displays a **My App Tracking Paused** card with a 1-tap `Resume App Tracking` button while keeping Kids Mode available below.
  - **Home Screen Widget Dismissible Card**: Displays a polished `Keep Focus in Glance` card directly below the Brain Fog card if the widget is supported, not yet added to the home screen, and not dismissed. Users can tap `[ Add Widget to Home Screen ]` or permanently dismiss it via `[ ✕ ]`. Auto-hides when widget is added or in Kids Mode.
  - **Conditional Extra Unlock Pass Card**: `_buildBypassTokenCard()` is **only shown on the Main Dashboard when the Daily Limit has been reached in Limit Mode** (`_focusMode == 1 && _dailyLimitMinutes > 0 && _totalSocialMinutes >= _dailyLimitMinutes`), positioned immediately below the Brain Fog card and above the Kids Mode card.
  - **Kids Mode Card & Active View**: Full-width stacked buttons (`Setup Apps & Time` + `Start Kids Mode`). When Kids Mode is active, transforms the dashboard into the dedicated **🧸 DefogMind Kids Mode** active countdown screen (`MM:SS`) with zero ads and a `🔐 Parent Unlock (End Kids Mode)` button.
- [`lib/presentation/screens/settings_screen.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/settings_screen.dart): Opens freely without a math challenge so users can inspect or adjust draft controls (`My App Tracking`, `Focus Mode`, `Manage Monitored Apps`, `Daily Limit Target`, `Extra Unlock Time`). Features a sticky bottom **`Save Settings`** button that enables on unsaved changes and triggers `MathChallengeDialog` right before saving and syncing to `FocusMonitorService`.
- [`lib/presentation/screens/app_selection_screen.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/app_selection_screen.dart): Monitored apps selector with stable top-pinning on screen open (`_pinnedTopPackages`), `All Apps` / `Selected Only` filter tabs, search bar, and in-memory icon caching. Powers Step 2 of onboarding (`isOnboarding: true`) and in-app settings management. Opens freely without math; in normal in-app mode, triggers `MathChallengeDialog` when tapping **`Apply Monitored Apps`** if changes were made. Pre-selects installed social apps automatically.
- [`lib/presentation/screens/kids_mode_setup_screen.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/kids_mode_setup_screen.dart): Allows parents to choose a Kids Session Time Limit (`15m`, `30m`, `45m`, `60m`, `90m`, `120m`) and select the **Allowed Apps for Kids** (with stable top-pinning).
- [`lib/presentation/widgets/parent_pin_dialog.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/widgets/parent_pin_dialog.dart): 4-Digit Parent PIN keypad + **Parent Recovery Security Question & Secret Answer** dropdown setup and verification (`"What was the brand of your first phone?"` [first priority], `"What was your childhood nickname?"`, `"Who was your childhood best friend?"`, `"What was the name of your first school?"`, `"What is your favorite childhood food?"`).
- [`lib/presentation/widgets/math_challenge_dialog.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/widgets/math_challenge_dialog.dart): Quick mental focus check (`A + B = ?` or `A − B = ?` with clean 2-digit numbers, zero multiplication, taking 2-3 seconds).

---

## 2. Strict Google Play & AdMob Policy Guardrails (NEVER Violate)

1. **NO `BIND_ACCESSIBILITY_SERVICE`**: Never add or use Android Accessibility APIs. All foreground app detection uses `UsageStatsManager` (`android.permission.PACKAGE_USAGE_STATS`).
2. **Zero Ads on System Overlays or During Kids Mode**:
   - `OverlayActivity.kt` and the floating Brain Fog meter must have **0% ads**.
   - While turning Kids Mode ON or while Kids Mode is active, **zero Banner or Interstitial ads** are displayed.
   - The throttled Interstitial Ad triggers **only AFTER** the parent verifies their 4-Digit Parent PIN to exit Kids Mode (or when updating Adult settings).
3. **Deferred AdMob Initialization**: `AdMobService.instance.initialize()` is deferred until `2.5s` after `HomeDashboard` mounts so cold start is never blocked.
4. **Medical & Non-Clinical Disclaimer**: Always preserve the disclaimer on Onboarding (sticky footer), Dashboard, Settings, and Blocker Shield:
   > *"DefogMind is a digital habit and productivity utility. It does not provide medical advice, diagnosis, or treatment for cognitive conditions."*
5. **Release APK Build Configuration** (`android/app/build.gradle.kts`):
   - `buildTypes.release` has `isMinifyEnabled = false` and `isShrinkResources = false` so R8 never strips Flutter JNI or Google Mobile Ads classes in release builds.

---

## 3. Core Engine Specifications

### 3.1. Progressive Brain Fog Fatigue Curve & Rest Recovery Math
- **Biological Progressive Fatigue Curve**:
  Instead of flat linear fatigue, mental exhaustion accelerates biologically the longer a session continues:
  | Continuous Active Usage | Rate of Fog Gain | Fog Milestone Reached | Mind Tier & Mascot Status |
  | :--- | :--- | :--- | :--- |
  | **0 – 45 min** | `+1%` per `1.5 minutes` (`+1.0 / 90.0` per sec) | **30% Fog** at 45 min | **Fresh Mind** (`<= 30%`, Mint `#10B981`) |
  | **45 – 70 min** | `+1%` per `1.25 minutes` (`+1.0 / 75.0` per sec) | **50% Fog** at 70 min | **Tired Mind** (`31% – 50%`, Amber `#F59E0B`) |
  | **70 – 100 min** | `+1%` per `1.0 minute` (`+1.0 / 60.0` per sec) | **80% Fog** at 100 min | **Heavy Mind** (`51% – 80%`, Orange `#FB923C`) |
  | **100 – 120 min+** | `+1%` per `1.0 minute` (`+1.0 / 60.0` per sec) | **100% Fog** at 120 min | **Overloaded Mind** (`> 80%`, Glitch Red `#EF4444`) |
  - Above 120 minutes, Brain Fog is capped at `100%` and status remains **Overloaded Mind**.
- **Break & Night Sleep Recovery Math**:
  - Decreases at `-1%` for every `3 minutes` (`1.0 / 180.0` per sec) spent outside monitored apps:
    - 15-minute break = `−5% fog`
    - 30-minute break = `−10% fog`
    - 1-hour break = `−20% fog`
    - 5 hours of night sleep = `100%` full recovery (0% Fresh).
- **Midnight Retention Policy**:
  - Daily screen time quota (`todaySocialMinutes`) resets to 0 at midnight (`12:00 AM`) for the new day's quota.
  - **Physiological Brain Fog does NOT reset at midnight**: Mental fatigue persists naturally until earned back via actual sleep/rest off the phone.
- **Offline Sleep Recovery on Service Boot**:
  - When the service or device starts, elapsed time since `KEY_LAST_SOCIAL_EXIT_MS` is credited at `-1%` per 3 minutes so waking up after sleeping naturally defogs the brain.

### 3.2. Mode-Specific Floating Pill / HUD Behavior
- **Limit Mode (`focusMode == 1`)**:
  - **10s on App Open**: Displays for 10 seconds whenever entering or switching to a monitored app (`"$word • ${todaySocialMinutes}m / ${dailyLimitMinutes}m used"`).
  - **10s on 5-Minute Milestones**: Peeks for 10 seconds every 5 minutes (5m, 10m, 15m, 20m, 25m...).
  - **Continuous in Final 5 Minutes**: When remaining daily time $\le 5$ minutes, stays visible continuously on screen as a gentle heads-up until the daily limit is reached.
  - **Removed 1% Fog Trigger**: Eliminates nagging popups every 30–60 seconds.
- **Awareness Mode (`focusMode == 0`)**:
  - **10s on App Open**: Displays for 10 seconds on app open (`"$word • $currentNetBrainFogPercent% Fog"`).
  - **10s on 5% Fog Milestones**: Peeks for 10 seconds every 5% increase in brain fog (5%, 10%, 15%, 20%, 25%, 30%...).
  - **10s on Tier Transitions**: Immediately peeks for 10 seconds when transitioning to the next state (Fresh $\rightarrow$ Tired at 31%, Tired $\rightarrow$ Heavy at 51%, Heavy $\rightarrow$ Overloaded at 81%).
  - **Clean Screen**: Smoothly fades away after 10 seconds so video playback, reading, and typing remain unobstructed.
- **Kids Mode (`isKidsModeActive == true`)**:
  - **10s on App Open**: Displays `🧸 Kids Time: Xm left` in Cyan (`#06B6D4`) for 10 seconds.
  - **10s on 5-Minute Milestones**: Peeks for 10 seconds at 25m, 20m, 15m (halfway), and 10m left.
  - **Continuous in Final 5 Minutes**: Stays visible continuously counting down seconds (`🧸 Kids Time: MM:SS`) in Amber (`#F59E0B`), switching to Red (`#EF4444`) in the final 1 minute.
  - **Launcher Exit**: Immediately hides when the child returns to the home screen.
- **Extra Unlock Bypass Active**:
  - Displays `⚡ Extra Unlock: MM:SS` continuously in Mint `#10B981` while inside a monitored app, counting down active usage up to the 15-minute absolute wall-clock ceiling.

### 3.3. 2×2 Home Screen Brain Clarity Widget
- Native 2×2 AppWidget implemented via `DefogMindWidgetProvider.kt` and `DefogMindWidgetUpdater.kt`.
- **Target Cell Geometry**: `minWidth="140dp"` / `minHeight="140dp"` with `targetCellWidth="2"` / `targetCellHeight="2"`.
- **Pinning Safety**: `AppWidgetManager.requestPinAppWidget` with deduplication check (`widgetIds.isNotEmpty()` returns early to prevent multiple duplicate widgets).
- **Home Dashboard Dismissible Card**: Clean `Keep Focus in Glance` card on `HomeDashboard` with 1-tap pinning and permanent `✕` close. Automatically suppressed once added or during Kids Mode.

### 3.4. Mental Math Challenge Trigger Points
The Mental Math Challenge (`MathChallengeDialog.show`) triggers at adult **commit/save** points (opening screens to view settings or apps is completely friction-free):
1. Switching **Focus Mode** between *Limit Mode* and *Awareness Mode* directly on the Main Dashboard.
2. Tapping **`Save Settings`** in [`SettingsScreen`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/settings_screen.dart) when draft changes have been made.
3. Tapping **`Apply Monitored Apps`** in [`AppSelectionScreen`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/app_selection_screen.dart) (`isOnboarding == false`) when monitored app selections were modified.

### 3.5. Kids Mode (Child Hand-Off) Sandbox & OEM Dialer Whitelist
- **Allow-List Only Enforcement**: Blocks all apps on the device except parent-selected `kidsAllowedPackages` (while `kidsRemainingSeconds > 0`) and essential system packages (`com.defogmind.app`, Home Screen Launchers, SystemUI, Permission Controllers, and Phone/Emergency Dialers including `TelecomManager.defaultDialerPackage`, `Intent.ACTION_DIAL` handlers, and OEM dialers like `com.sh.smart.caller`).
- **Complete Adult Isolation**:
  - While Kids Mode is ON, Adult Brain Fog never increases and continues natural recovery (`-1%` per `3 minutes`).
  - Kids usage is tracked per-package under `KEY_KIDS_USAGE_PREFIX + pkg` and subtracted from total system usage when computing Adult social minutes (`adultOnlyMs = maxOf(0, totalSystemMs - kidsMs)`).
  - Both the Brain Fog card and Today's App Usage breakdown display **`Adult: Xm • 🧸 Kids: Ym`**.
- **4-Digit Parent PIN + Security Question Recovery**:
  - Turning Kids Mode OFF (`🔐 Parent Unlock`) or editing Kids Mode setup requires the 4-digit Parent PIN.
  - If forgotten, the parent recovers their PIN by answering their chosen **Parent Recovery Security Question** (`parent_security_question` / `parent_security_answer`).
