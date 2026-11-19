class AppConfig {
  const AppConfig._();

  static const firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');
  static const firebaseSetupCommand =
      'flutter run --dart-define=FIREBASE_ENABLED=true';
  static const firebaseNativeSetupMessage =
      'Add the Firebase native configuration files for each target platform '
      '(google-services.json for Android and GoogleService-Info.plist for iOS) '
      'before enabling Firebase.';
  static const adsEnabled = bool.fromEnvironment('ADS_ENABLED');
  static const rewardedAdUnitId = String.fromEnvironment('REWARDED_AD_UNIT_ID');
}
