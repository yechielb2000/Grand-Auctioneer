import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/models/user_account.dart';
import '../../features/auth/domain/auth_service.dart';
import '../../features/auth/domain/user_repository.dart';
import '../../features/auth/domain/starter_content_repository.dart';

class FirebaseGoogleAuthService implements AuthService {
  FirebaseGoogleAuthService({
    required FirebaseAuth auth,
    required UserRepository users,
    required StarterContentRepository starterContent,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _users = users,
        _starterContent = starterContent,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final UserRepository _users;
  final StarterContentRepository _starterContent;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<UserAccount?> watchCurrentUser() =>
      _auth.authStateChanges().asyncMap(_loadAccount);

  Future<UserAccount?> _loadAccount(User? user) async {
    if (user == null) return null;
    final account = await _users.getOrCreate(_newAccount(user));
    await _starterContent.provisionFor(user.uid);
    return account;
  }

  @override
  Future<UserAccount> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw StateError('Google sign-in was cancelled.');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    final firebaseUser = result.user;
    if (firebaseUser == null) {
      throw StateError('Firebase sign-in completed without a user account.');
    }

    final profile = await _users.getOrCreate(_newAccount(firebaseUser));
    await _starterContent.provisionFor(firebaseUser.uid);
    return profile;
  }

  UserAccount _newAccount(User user) => UserAccount(
        uid: user.uid,
        displayName: user.displayName ?? 'Empire Builder',
        email: user.email ?? '',
        photoUrl: user.photoURL ?? '',
        cashBalance: 10000,
        gems: 50,
        netWorth: 10000,
        createdAt: user.metadata.creationTime ?? DateTime.now().toUtc(),
      );

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
