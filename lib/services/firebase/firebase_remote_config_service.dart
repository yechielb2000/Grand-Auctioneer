import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class FirebaseRemoteConfigService {
  FirebaseRemoteConfigService({
    required FirebaseRemoteConfig remoteConfig,
    required FirebaseAnalytics analytics,
  })  : _remoteConfig = remoteConfig,
        _analytics = analytics;

  final FirebaseRemoteConfig _remoteConfig;
  final FirebaseAnalytics _analytics;

  Future<void> initialize() async {
    await _remoteConfig.setDefaults(const {
      'auction_extension_seconds': 15,
      'daily_reward_limit': 5,
    });
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 5),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    try {
      await _remoteConfig.fetchAndActivate();
    } on FirebaseException catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Firebase Remote Config',
        context: ErrorDescription('while fetching app configuration'),
      ));
    }
    try {
      await _analytics.logAppOpen();
    } on FirebaseException catch (error, stackTrace) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Firebase Analytics',
        context: ErrorDescription('while recording the app-open event'),
      ));
    }
  }

  int get auctionExtensionSeconds {
    final seconds = _remoteConfig.getInt('auction_extension_seconds');
    if (seconds > 0 && seconds <= 120) return seconds;
    _reportInvalidValue('auction_extension_seconds', seconds);
    return 15;
  }

  int get dailyRewardLimit {
    final limit = _remoteConfig.getInt('daily_reward_limit');
    if (limit >= 0 && limit <= 20) return limit;
    _reportInvalidValue('daily_reward_limit', limit);
    return 5;
  }

  void _reportInvalidValue(String key, int value) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: FormatException('Remote Config "$key" has invalid value $value.'),
      library: 'Firebase Remote Config',
      context: ErrorDescription('while reading a game configuration value'),
    ));
  }
}
