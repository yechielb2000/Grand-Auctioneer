class AppConfig {
  const AppConfig._();

  static const firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');
  static const adsEnabled = bool.fromEnvironment('ADS_ENABLED');
  static const rewardedAdUnitId = String.fromEnvironment('REWARDED_AD_UNIT_ID');
}
