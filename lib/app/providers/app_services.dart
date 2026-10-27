import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../features/auth/domain/auth_service.dart';
import '../../features/auth/domain/user_repository.dart';
import '../../features/auction/domain/auction_repository.dart';
import '../../features/inventory/domain/asset_repository.dart';
import '../../features/map_properties/domain/property_repository.dart';
import '../../services/firebase/firebase_auth_service.dart';
import '../../services/firebase/firebase_notification_service.dart';
import '../../services/firebase/firebase_remote_config_service.dart';
import '../../services/firebase/firebase_storage_service.dart';
import '../../services/firebase/firestore_game_repositories.dart';

class AppServices {
  AppServices._({
    required this.auth,
    required this.analytics,
    required this.users,
    required this.properties,
    required this.assets,
    required this.auctions,
    required this.storage,
    required this.remoteConfig,
    required this.notifications,
  });

  final AuthService auth;
  final FirebaseAnalytics analytics;
  final UserRepository users;
  final PropertyRepository properties;
  final AssetRepository assets;
  final AuctionRepository auctions;
  final FirebaseStorageService storage;
  final FirebaseRemoteConfigService remoteConfig;
  final FirebaseNotificationService notifications;

  static Future<AppServices> initialize() async {
    final firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(persistenceEnabled: true);

    final users = FirestoreUserRepository(firestore);
    final analytics = FirebaseAnalytics.instance;
    final remoteConfig = FirebaseRemoteConfigService(
      remoteConfig: FirebaseRemoteConfig.instance,
      analytics: analytics,
    );
    final notifications = FirebaseNotificationService(
      messaging: FirebaseMessaging.instance,
      auth: FirebaseAuth.instance,
      users: users,
    );
    await remoteConfig.initialize();
    await notifications.initialize();

    return AppServices._(
      auth: FirebaseGoogleAuthService(auth: FirebaseAuth.instance, users: users),
      analytics: analytics,
      users: users,
      properties: FirestorePropertyRepository(firestore),
      assets: FirestoreAssetRepository(firestore),
      auctions: FirestoreAuctionRepository(firestore),
      storage: FirebaseStorageService(FirebaseStorage.instance),
      remoteConfig: remoteConfig,
      notifications: notifications,
    );
  }

  Future<void> dispose() => notifications.dispose();
}
