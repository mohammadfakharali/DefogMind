import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/ad_constants.dart';

class AdMobService {
  AdMobService._internal();
  static final AdMobService instance = AdMobService._internal();

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  DateTime? _lastInterstitialShownAt;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdMobService] Google Mobile Ads initialized successfully.');
      preloadInterstitial();
      preloadRewarded();
    } catch (e) {
      debugPrint('[AdMobService] Error initializing Google Mobile Ads: $e');
    }
  }

  // --- Interstitial Ads (Throttled to >= 4 mins) ---

  void preloadInterstitial() {
    if (_interstitialAd != null || _isInterstitialLoading) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: AdConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('[AdMobService] Interstitial Ad loaded.');
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
          debugPrint('[AdMobService] Failed to load Interstitial Ad: $error');
        },
      ),
    );
  }

  bool showInterstitialIfAllowed() {
    final now = DateTime.now();
    if (_lastInterstitialShownAt != null) {
      final elapsed = now.difference(_lastInterstitialShownAt!);
      if (elapsed < AdConstants.interstitialThrottleDuration) {
        debugPrint('[AdMobService] Interstitial throttled: only $elapsed elapsed.');
        return false;
      }
    }

    if (_interstitialAd != null) {
      _lastInterstitialShownAt = now;
      _interstitialAd!.show();
      return true;
    } else {
      preloadInterstitial();
      return false;
    }
  }

  // --- Rewarded Video Ads (Oxygen Passes) ---

  void preloadRewarded() {
    if (_rewardedAd != null || _isRewardedLoading) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: AdConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('[AdMobService] Rewarded Video loaded.');
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              preloadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              preloadRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          _rewardedAd = null;
          debugPrint('[AdMobService] Failed to load Rewarded Ad: $error');
        },
      ),
    );
  }

  void showRewardedAd({
    required Function() onRewardEarned,
    required Function() onAdUnavailable,
  }) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (adWithoutView, reward) {
          debugPrint('[AdMobService] User earned reward: ${reward.amount} ${reward.type}');
          onRewardEarned();
        },
      );
    } else {
      preloadRewarded();
      onAdUnavailable();
    }
  }

  BannerAd createBannerAd({required Function() onAdLoaded, required Function(LoadAdError) onAdFailed}) {
    return BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onAdLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailed(error);
        },
      ),
    );
  }
}

