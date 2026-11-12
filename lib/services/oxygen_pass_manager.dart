import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';

class OxygenPassManager {
  static const String _keyDurationSeconds = 'oxygen_pass_duration_seconds';
  static const String _keyFreePassesRemaining = 'free_passes_remaining';
  static const String _keyLastResetDay = 'last_pass_reset_day';
  static const String _keyBonusPasses = 'bonus_passes_earned';

  static const int defaultDurationSeconds = 300; // 5 min
  static const int maxFreeDailyPasses = 2;

  static Future<int> getPassDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDurationSeconds) ?? defaultDurationSeconds;
  }

  static Future<void> setPassDuration(int durationSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDurationSeconds, durationSeconds);
  }

  static Future<int> getRemainingPasses() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkDailyReset(prefs);
    final free = prefs.getInt(_keyFreePassesRemaining) ?? maxFreeDailyPasses;
    final bonus = prefs.getInt(_keyBonusPasses) ?? 0;
    return free + bonus;
  }

  static Future<bool> usePass() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkDailyReset(prefs);

    int free = prefs.getInt(_keyFreePassesRemaining) ?? maxFreeDailyPasses;
    int bonus = prefs.getInt(_keyBonusPasses) ?? 0;

    if (free > 0) {
      free--;
      await prefs.setInt(_keyFreePassesRemaining, free);
      final duration = await getPassDuration();
      await UsageService.triggerOxygenPass(duration);
      return true;
    } else if (bonus > 0) {
      bonus--;
      await prefs.setInt(_keyBonusPasses, bonus);
      final duration = await getPassDuration();
      await UsageService.triggerOxygenPass(duration);
      return true;
    }
    return false;
  }

  static Future<void> addBonusPassFromAd() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyBonusPasses) ?? 0;
    await prefs.setInt(_keyBonusPasses, current + 1);
  }

  static Future<void> _checkDailyReset(SharedPreferences prefs) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final lastReset = prefs.getString(_keyLastResetDay);

    if (lastReset != todayKey) {
      await prefs.setString(_keyLastResetDay, todayKey);
      await prefs.setInt(_keyFreePassesRemaining, maxFreeDailyPasses);
      await prefs.setInt(_keyBonusPasses, 0);
    }
  }
}

