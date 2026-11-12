import 'package:flutter/material.dart';

class SocialAppInfo {
  final String packageName;
  final String name;
  final IconData icon;
  final Color accentColor;

  const SocialAppInfo({
    required this.packageName,
    required this.name,
    required this.icon,
    required this.accentColor,
  });
}

class SocialApps {
  static const List<SocialAppInfo> defaultApps = [
    SocialAppInfo(
      packageName: 'com.instagram.android',
      name: 'Instagram',
      icon: Icons.camera_alt_outlined,
      accentColor: Color(0xFFE1306C),
    ),
    SocialAppInfo(
      packageName: 'com.zhiliaoapp.musically',
      name: 'TikTok',
      icon: Icons.music_note_outlined,
      accentColor: Color(0xFF00F2FE),
    ),
    SocialAppInfo(
      packageName: 'com.google.android.youtube',
      name: 'YouTube',
      icon: Icons.play_circle_outline,
      accentColor: Color(0xFFFF0000),
    ),
    SocialAppInfo(
      packageName: 'com.twitter.android',
      name: 'X (Twitter)',
      icon: Icons.tag,
      accentColor: Color(0xFF1DA1F2),
    ),
    SocialAppInfo(
      packageName: 'com.facebook.katana',
      name: 'Facebook',
      icon: Icons.facebook,
      accentColor: Color(0xFF1877F2),
    ),
    SocialAppInfo(
      packageName: 'com.snapchat.android',
      name: 'Snapchat',
      icon: Icons.chat_bubble_outline,
      accentColor: Color(0xFFFFFC00),
    ),
    SocialAppInfo(
      packageName: 'com.reddit.frontpage',
      name: 'Reddit',
      icon: Icons.forum_outlined,
      accentColor: Color(0xFFFF4500),
    ),
  ];

  static List<String> get defaultPackageList =>
      defaultApps.map((a) => a.packageName).toList();

  static String getAppName(String packageName) {
    for (final app in defaultApps) {
      if (app.packageName == packageName) {
        return app.name;
      }
    }
    // Fallback: extract last segment
    final parts = packageName.split('.');
    return parts.isNotEmpty ? parts.last.toUpperCase() : packageName;
  }
}

