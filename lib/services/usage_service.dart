import 'package:flutter/services.dart';

class UsageService {
  static const MethodChannel _channel = MethodChannel('com.defogmind/platform');

  static Future<bool> checkUsagePermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('checkUsagePermission');
      return hasPermission;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestUsagePermission() async {
    try {
      await _channel.invokeMethod('requestUsagePermission');
    } on PlatformException catch (_) {}
  }

  static Future<bool> checkOverlayPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('checkOverlayPermission');
      return hasPermission;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (_) {}
  }

  static Future<bool> checkNotificationPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('checkNotificationPermission');
      return hasPermission;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } on PlatformException catch (_) {}
  }

  static Future<void> startFocusService({
    required int mode,
    bool adultTrackingEnabled = true,
    required int passDuration,
    required int dailyLimit,
    required List<String> packages,
  }) async {
    try {
      await _channel.invokeMethod('startFocusService', {
        'mode': mode,
        'adultTrackingEnabled': adultTrackingEnabled,
        'passDuration': passDuration,
        'dailyLimit': dailyLimit,
        'packages': packages,
      });
    } on PlatformException catch (_) {}
  }

  static Future<void> stopFocusService() async {
    try {
      await _channel.invokeMethod('stopFocusService');
    } on PlatformException catch (_) {}
  }

  static Future<void> updateServiceConfig({
    required int mode,
    bool adultTrackingEnabled = true,
    required int passDuration,
    required int dailyLimit,
    required List<String> packages,
  }) async {
    try {
      await _channel.invokeMethod('updateServiceConfig', {
        'mode': mode,
        'adultTrackingEnabled': adultTrackingEnabled,
        'passDuration': passDuration,
        'dailyLimit': dailyLimit,
        'packages': packages,
      });
    } on PlatformException catch (_) {}
  }

  static Future<void> triggerOxygenPass(int durationSeconds) async {
    try {
      await _channel.invokeMethod('triggerOxygenPass', {
        'durationSeconds': durationSeconds,
      });
    } on PlatformException catch (_) {}
  }

  static Future<bool> checkBatteryExemption() async {
    try {
      final bool isExempt = await _channel.invokeMethod('checkBatteryExemption');
      return isExempt;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestBatteryExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryExemption');
    } on PlatformException catch (_) {}
  }

  static Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } on PlatformException catch (_) {}
  }

  static Future<Map<String, int>> getDailyUsageStats(List<String> packages) async {
    try {
      final Map? rawMap = await _channel.invokeMethod('getDailyUsageStats', {
        'packages': packages,
      });
      if (rawMap == null) return {};
      return rawMap.map((key, value) => MapEntry(key.toString(), (value as num).toInt()));
    } on PlatformException {
      return {};
    }
  }

  static List<Map<String, String>>? _cachedInstalledApps;

  static Future<List<Map<String, String>>> getInstalledApps({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedInstalledApps != null && _cachedInstalledApps!.isNotEmpty) {
      return _cachedInstalledApps!;
    }
    try {
      final List? rawList = await _channel.invokeMethod('getInstalledApps');
      if (rawList == null) return _cachedInstalledApps ?? [];
      final apps = rawList.map((item) => Map<String, String>.from(item as Map)).toList();
      _cachedInstalledApps = apps;
      return apps;
    } on PlatformException {
      return _cachedInstalledApps ?? [];
    }
  }

  static Future<int> getCurrentBrainFog() async {
    try {
      final int? fog = await _channel.invokeMethod('getCurrentBrainFog');
      return fog ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> getBrainFogStatus() async {
    try {
      final Map? raw = await _channel.invokeMethod('getBrainFogStatus');
      if (raw == null) return {'percentage': 0, 'statusWord': 'Fresh', 'totalSocialMinutes': 0};
      return Map<String, dynamic>.from(raw);
    } on PlatformException {
      return {'percentage': 0, 'statusWord': 'Fresh', 'totalSocialMinutes': 0};
    }
  }

  static Future<void> setKidsMode({
    required bool active,
    required int limitMinutes,
    required int remainingSeconds,
    required List<String> allowedPackages,
  }) async {
    try {
      await _channel.invokeMethod('setKidsMode', {
        'active': active,
        'limitMinutes': limitMinutes,
        'remainingSeconds': remainingSeconds,
        'allowedPackages': allowedPackages,
      });
    } on PlatformException catch (_) {}
  }

  static Future<Map<String, dynamic>> getKidsModeStatus() async {
    try {
      final Map? raw = await _channel.invokeMethod('getKidsModeStatus');
      if (raw == null) {
        return {
          'isActive': false,
          'limitMinutes': 30,
          'remainingSeconds': 1800,
          'allowedPackages': <String>[],
          'kidsUsageMillis': <String, int>{},
        };
      }
      final rawKidsMap = raw['kidsUsageMillis'] as Map?;
      final Map<String, int> kidsUsageMillis = {};
      if (rawKidsMap != null) {
        rawKidsMap.forEach((k, v) {
          kidsUsageMillis[k.toString()] = (v as num).toInt();
        });
      }
      final rawAllowed = raw['allowedPackages'] as List?;
      final List<String> allowedPackages = rawAllowed != null
          ? rawAllowed.map((e) => e.toString()).toList()
          : <String>[];

      return {
        'isActive': (raw['isActive'] as bool?) ?? false,
        'limitMinutes': (raw['limitMinutes'] as num?)?.toInt() ?? 30,
        'remainingSeconds': (raw['remainingSeconds'] as num?)?.toInt() ?? 1800,
        'allowedPackages': allowedPackages,
        'kidsUsageMillis': kidsUsageMillis,
      };
    } on PlatformException {
      return {
        'isActive': false,
        'limitMinutes': 30,
        'remainingSeconds': 1800,
        'allowedPackages': <String>[],
        'kidsUsageMillis': <String, int>{},
      };
    }
  }
}
