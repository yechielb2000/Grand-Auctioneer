import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/domain/user_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage _) async {
  await Firebase.initializeApp();
}

class FirebaseNotificationService {
  FirebaseNotificationService({
    required FirebaseMessaging messaging,
    required FirebaseAuth auth,
    required UserRepository users,
  })  : _messaging = messaging,
        _auth = auth,
        _users = users;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final UserRepository _users;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _authSubscription = _auth.authStateChanges().listen(
      (user) {
        if (user != null) {
          unawaited(
            _saveToken(user.uid).catchError(_reportBackgroundError),
          );
        }
      },
      onError: _reportBackgroundError,
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) {
        final user = _auth.currentUser;
        if (user != null) {
          unawaited(
            _users.saveMessagingToken(user.uid, token).catchError(
                  _reportBackgroundError,
                ),
          );
        }
      },
      onError: _reportBackgroundError,
    );
  }

  Future<void> _saveToken(String uid) async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _users.saveMessagingToken(uid, token);
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }

  void _reportBackgroundError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Firebase notification service',
        context: ErrorDescription('while updating an FCM registration token'),
      ),
    );
  }
}
