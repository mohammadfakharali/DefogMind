enum FogTier {
  cleanMind(0, 'Fresh Mind', 'Clear & Focused', '🧠 Fresh', 'Fresh'),
  mildHaze(1, 'Tired Mind', 'Time for a break', '🧠 Tired', 'Tired'),
  denseFog(2, 'Heavy Mind', 'High mental load', '🧠 Heavy', 'Heavy'),
  sludgeGlitch(3, 'Overloaded Mind', 'High mental strain', '🧠 Overloaded', 'Overloaded');

  final int level;
  final String title;
  final String description;
  final String meterLabel;
  final String statusWord;

  const FogTier(this.level, this.title, this.description, this.meterLabel, this.statusWord);
}

class FogCalculationResult {
  final double fogPercentage; // 0.0 to 100.0%
  final FogTier tier;
  final int totalSocialMinutes;
  final int passiveDecayMinutes;

  const FogCalculationResult({
    required this.fogPercentage,
    required this.tier,
    required this.totalSocialMinutes,
    required this.passiveDecayMinutes,
  });
}

class FogCalculator {
  /// Unified Brain Fog calculation across both Awareness Mode (focusMode == 0)
  /// and Limit Mode (focusMode == 1):
  /// Synchronized 100% with the centralized Brain Fog store maintained by FocusMonitorService
  /// (+1% per 1 min active use, -1% per 2.5 mins rest).
  static FogCalculationResult calculate({
    required int focusMode,
    required int totalSocialMinutes,
    required int passiveRecoveryMinutes,
    required int dailyLimitMinutes,
    int? cachedServiceFog,
  }) {
    final double netPercentage = (cachedServiceFog ?? 0).toDouble().clamp(0.0, 100.0);

    // Determine status tier from percentage (0-30: Fresh, 31-60: Tired, 61-90: Heavy, 91-100: Overloaded)
    final int roundedPct = netPercentage.round();
    final FogTier tier;
    if (roundedPct <= 30) {
      tier = FogTier.cleanMind;
    } else if (roundedPct <= 60) {
      tier = FogTier.mildHaze;
    } else if (roundedPct <= 90) {
      tier = FogTier.denseFog;
    } else {
      tier = FogTier.sludgeGlitch;
    }

    return FogCalculationResult(
      fogPercentage: netPercentage,
      tier: tier,
      totalSocialMinutes: totalSocialMinutes,
      passiveDecayMinutes: passiveRecoveryMinutes,
    );
  }
}
