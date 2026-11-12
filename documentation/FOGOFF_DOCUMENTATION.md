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
- [`MainActivity.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/MainActivity.kt): Hosts the `com.defogmind/platform` MethodChannel. Runs heavy `UsageStatsManager` and `PackageManager.getInstalledApplications` queries on a background single-thread executor (`bgExecutor`) so the main UI thread never skips frames.
- [`FocusMonitorService.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/FocusMonitorService.kt): High-performance background `Service` (`foregroundServiceType="specialUse"`). Runs its 1-second foreground check loop on a dedicated background `HandlerThread("DefogMindMonitorBg")` and posts UI overlay updates to `mainHandler`. Implements `queryExactTodayUsageMap` with a 10-second shared cache, Awareness & Limit Mode floating Brain Fog meters, Dual-Clock Extra Unlock countdown, and the Kids Mode sandbox.
- [`OverlayActivity.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/OverlayActivity.kt): Full-screen native blocker shield (`#0B0F17`) with compact density-aware (`dp()`) buttons. Renders both the **Adult Focus Shield** (`DAILY LIMIT REACHED` + 10-second breathing gate) and the **Kids Mode Shield** (`🔒 LOCKED IN KIDS MODE` / `⏰ KIDS TIME FINISHED`).
- [`PassStorage.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/PassStorage.kt): Unified cross-platform storage bridge reading/writing `FlutterSharedPreferences` (`flutter.free_passes_remaining`, `flutter.bonus_passes_earned`, `flutter.last_pass_reset_day`, `flutter.oxygen_pass_duration_seconds`).
- [`BootReceiver.kt`](file:///E:/Dev/Apps/DefogMind/android/app/src/main/kotlin/com/defogmind/app/BootReceiver.kt): Automatically restarts `FocusMonitorService` on `BOOT_COMPLETED`.

### Flutter UI & Services (`lib/`)
- [`lib/main.dart`](file:///E:/Dev/Apps/DefogMind/lib/main.dart): `DefogMindRootApp` entry point with fast permission/onboarding check (`1000ms` timeout, zero artificial delay) and static `_BrandedSplashScreen` (`assets/images/app_logo.png` + `DefogMind` title).
- [`lib/presentation/screens/onboarding_disclosure_screen.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/onboarding_disclosure_screen.dart):
  - **Step 1 of 3 (Focus Style & Limits)**: Both focus modes start unselected (`_selectedMode = null`) with high-contrast, prominent cards so both choices are clear. If `Awareness Mode` (`_selectedMode = 0`) is selected, no sub-settings are displayed and the CTA button enables immediately (`Next: Select Apps to Track`). If `Limit Mode` (`_selectedMode = 1`) is selected, its two settings expand with a **circulating comet moving border effect** (`_MovingCometBorderCard`):
    1. Card 1 (`Total Daily Limit`) features a traveling light beam with a glowing head and tapered tail circulating continuously around its rounded perimeter. Header row cleanly displays the chosen limit without right-side overflow badges.
    2. Once a limit is tapped (or slider released), Card 1 locks into a calm mint border, the circulating comet jumps down to Card 2 (`Extra Unlock Time`), and the view automatically and smoothly scrolls down to bring Card 2 into full view above the sticky button.
    3. Out-of-order selection support: If the user selects Card 2 first, Card 2 locks in immediately and never displays the moving border; the view smoothly scrolls to bring Card 1 into view so the user can easily finish setting their limit.
    4. Once both are selected, all animations stop, both cards settle into confirmed mint borders, and the sticky bottom CTA button enables in vibrant mint (`Next: Select Apps to Track`).
  - **Step 2 of 3 (Select Apps to Track)**: Navigates to `AppSelectionScreen(isOnboarding: true)`. Top "Suggested Social Apps" carousel removed. Automatically detects and pre-selects known social apps **only if they are actually installed on the device** and pins them to the top. Bottom CTA button (`Next: Privacy & Permissions`) saves the package list and returns to Step 3.
  - **Step 3 of 3 (Privacy & Permissions)**: Top `100% On-Device Privacy Guarantee` banner positioned directly above the permission cards (in compliance with Google Play Prominent Disclosure guidelines). Cleanly organized into **REQUIRED** (`Usage Access` & `Display Over Other Apps`) and **RECOMMENDED** (`Background Protection` & `Focus Notifications`) sections with "Allow" buttons. Once both required permissions are granted, smoothly auto-scrolls down to reveal recommended permissions, and the sticky bottom button (`Start Using DefogMind`) initializes native focus tracking and launches `HomeDashboard`.
- [`lib/presentation/screens/home_dashboard.dart`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/home_dashboard.dart):
  - **Adult Dashboard**: AppBar shows compact `DefogMind` title (`🧸 DefogMind Kids Mode` during Kids Mode). Mode switcher (`Awareness Mode` vs `Limit Mode`), `BrainFogVisualizer` card with `Adult Social Time`, tappable `Daily Target ✎` shortcut (opens `SettingsScreen`), `Adult: Xm • 🧸 Kids: Ym` split badge, and `Daily Limit Used` progress bar. When My App Tracking is paused (`adult_tracking_enabled == false`), displays a **My App Tracking Paused** card with a 1-tap `Resume App Tracking` button while keeping Kids Mode available below.
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

### 3.1. Unified Linear Brain Fog & Break Recovery Math
- **Active Usage Increase (`+1%` per 1 minute)**:
  - Increases linearly at `+1%` for every `1 minute` spent inside a monitored app (`+1.0 / 60.0` per second):
    - `0% – 30%`: `🧠 Fresh • X% Fog` (`Fresh Mind`, Mint `#10B981`)
    - `31% – 60%`: `🧠 Tired • X% Fog` (`Tired Mind`, Amber `#F59E0B`)
    - `61% – 90%`: `🧠 Heavy • X% Fog` (`Heavy Mind`, Orange `#FB923C`)
    - `91% – 100%`: `🧠 Overloaded • X% Fog` (`Overloaded Mind`, Coral `#EF4444`)
- **Break Recovery (`-1%` per 3 minutes)**:
  - Decreases linearly at `-1%` for every `3 minutes` (`1.0 / 180.0` per second) spent outside monitored apps (full `100%` to `0%` recovery in `5 hours`).
- **Mode-Specific Floating Meter Behavior**:
  - **Awareness Mode (`focusMode == 0`)**: Floating Brain Fog meter stays visible continuously inside monitored apps.
  - **Limit Mode (`focusMode == 1`)**: Floating Brain Fog meter fades in (`350ms`), stays visible for **4 seconds (`4000L`)**, and fades out (`400ms`) **immediately when entering a monitored app** AND **on every `1%` Brain Fog change**. When an Extra Unlock Pass is active, displays `⚡ Extra Unlock: MM:SS` continuously.

### 3.2. Mental Math Challenge Trigger Points
The Mental Math Challenge (`MathChallengeDialog.show`) triggers at adult **commit/save** points (opening screens to view settings or apps is completely friction-free):
1. Switching **Focus Mode** between *Limit Mode* and *Awareness Mode* directly on the Main Dashboard.
2. Tapping **`Save Settings`** in [`SettingsScreen`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/settings_screen.dart) when draft changes have been made.
3. Tapping **`Apply Monitored Apps`** in [`AppSelectionScreen`](file:///E:/Dev/Apps/DefogMind/lib/presentation/screens/app_selection_screen.dart) (`isOnboarding == false`) when monitored app selections were modified.

### 3.3. Kids Mode (Child Hand-Off) Sandbox & OEM Dialer Whitelist
- **Allow-List Only Enforcement**: Blocks all apps on the device except parent-selected `kidsAllowedPackages` (while `kidsRemainingSeconds > 0`) and essential system packages (`com.defogmind.app`, Home Screen Launchers, SystemUI, Permission Controllers, and Phone/Emergency Dialers including `TelecomManager.defaultDialerPackage`, `Intent.ACTION_DIAL` handlers, and OEM dialers like `com.sh.smart.caller`).
- **Complete Adult Isolation**:
  - While Kids Mode is ON, Adult Brain Fog never increases and continues natural recovery (`-1%` per `3 minutes`).
  - Kids usage is tracked per-package under `KEY_KIDS_USAGE_PREFIX + pkg` and subtracted from total system usage when computing Adult social minutes (`adultOnlyMs = maxOf(0, totalSystemMs - kidsMs)`).
  - Both the Brain Fog card and Today's App Usage breakdown display **`Adult: Xm • 🧸 Kids: Ym`**.
- **4-Digit Parent PIN + Security Question Recovery**:
  - Turning Kids Mode OFF (`🔐 Parent Unlock`) or editing Kids Mode setup requires the 4-digit Parent PIN.
  - If forgotten, the parent recovers their PIN by answering their chosen **Parent Recovery Security Question** (`parent_security_question` / `parent_security_answer`).
