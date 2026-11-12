import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'services/usage_service.dart';
import 'presentation/screens/onboarding_disclosure_screen.dart';
import 'presentation/screens/home_dashboard.dart';

// Global Theme Notifier for instant dynamic theme changes across the app
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference: 'system' (default), 'light', or 'dark'
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('app_theme_mode') ?? 'system';
  if (savedTheme == 'light') {
    appThemeModeNotifier.value = ThemeMode.light;
  } else if (savedTheme == 'dark') {
    appThemeModeNotifier.value = ThemeMode.dark;
  } else {
    appThemeModeNotifier.value = ThemeMode.system;
  }

  runApp(const DefogMindRootApp());
}

Future<void> updateAppThemeMode(ThemeMode mode) async {
  appThemeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  final String modeStr = mode == ThemeMode.light
      ? 'light'
      : (mode == ThemeMode.dark ? 'dark' : 'system');
  await prefs.setString('app_theme_mode', modeStr);
}

class DefogMindRootApp extends StatefulWidget {
  const DefogMindRootApp({super.key});

  @override
  State<DefogMindRootApp> createState() => _DefogMindRootAppState();
}

class _DefogMindRootAppState extends State<DefogMindRootApp> {
  bool _isChecking = true;
  bool _needsOnboarding = true;

  @override
  void initState() {
    super.initState();
    _initializeAppAndPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/app_logo.png'), context);
  }

  Future<void> _initializeAppAndPermissions() async {
    bool completedBefore = false;
    bool hasUsage = true;
    bool hasOverlay = true;

    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 1000));
      completedBefore = prefs.getBool('onboarding_completed') ?? false;
    } catch (_) {
      completedBefore = false;
    }

    try {
      final results = await Future.wait([
        UsageService.checkUsagePermission(),
        UsageService.checkOverlayPermission(),
      ]).timeout(const Duration(milliseconds: 1000));
      hasUsage = results[0];
      hasOverlay = results[1];
    } catch (_) {
      hasUsage = completedBefore;
      hasOverlay = completedBefore;
    }

    if (!completedBefore && hasUsage && hasOverlay) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey('focus_mode')) {
          completedBefore = true;
          await prefs.setBool('onboarding_completed', true);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _needsOnboarding = !completedBefore || !hasUsage || !hasOverlay;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'DefogMind: Screen Time & Focus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _isChecking
              ? const _BrandedSplashScreen()
              : (_needsOnboarding
                  ? const OnboardingDisclosureScreen()
                  : const HomeDashboard()),
        );
      },
    );
  }
}

class _BrandedSplashScreen extends StatelessWidget {
  const _BrandedSplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Defog',
                          style: TextStyle(
                            color: AppTheme.textPrimary(context),
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const TextSpan(
                          text: 'Mind',
                          style: TextStyle(
                            color: AppTheme.mint,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Clear Mind • Focused Life',
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        backgroundColor: isDark ? const Color(0xFF161E2E) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mint),
                        minHeight: 3.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preparing focus engine...',
                    style: TextStyle(
                      color: AppTheme.textMuted(context),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Text(
                  'SCREEN TIME & DIGITAL WELLBEING',
                  style: TextStyle(
                    color: AppTheme.textMuted(context),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
