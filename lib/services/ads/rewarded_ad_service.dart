import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  RewardedAdService(this._adUnitId);

  final String _adUnitId;

  Future<void> initialize() async {
    if (_adUnitId.isEmpty) {
      throw StateError('REWARDED_AD_UNIT_ID must be set when ads are enabled.');
    }
    await MobileAds.instance.initialize();
  }

  Future<bool> showRewardedAd() {
    if (_adUnitId.isEmpty) {
      throw StateError('REWARDED_AD_UNIT_ID must be set when ads are enabled.');
    }

    final result = Completer<bool>();
    var earnedReward = false;
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!result.isCompleted) result.complete(earnedReward);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!result.isCompleted) result.completeError(error);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => earnedReward = true);
        },
        onAdFailedToLoad: (error) {
          if (!result.isCompleted) result.completeError(error);
        },
      ),
    );
    return result.future;
  }
}
