class AdConstants {
  // Toggle this to false when you are ready to publish with live AdMob IDs
  static const bool isTesting = true;

  // Official Google Android Test Ad Unit IDs
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  // Production Ad Unit IDs (Paste your live AdMob IDs here before publishing)
  static const String prodBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String prodInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';
  static const String prodRewardedId = 'ca-app-pub-XXXXXXXXXXXXXXXX/WWWWWWWWWW';

  static String get bannerAdUnitId => isTesting ? testBannerId : prodBannerId;
  static String get interstitialAdUnitId => isTesting ? testInterstitialId : prodInterstitialId;
  static String get rewardedAdUnitId => isTesting ? testRewardedId : prodRewardedId;

  // Interstitial minimum cooldown throttle (4 minutes)
  static const Duration interstitialThrottleDuration = Duration(minutes: 4);
}

