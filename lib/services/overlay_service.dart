import 'usage_service.dart';

class OverlayService {
  static Future<bool> isOverlayPermissionGranted() async {
    return await UsageService.checkOverlayPermission();
  }

  static Future<void> requestOverlayPermission() async {
    await UsageService.requestOverlayPermission();
  }

  static Future<void> triggerOxygenPass(int durationSeconds) async {
    await UsageService.triggerOxygenPass(durationSeconds);
  }
}

