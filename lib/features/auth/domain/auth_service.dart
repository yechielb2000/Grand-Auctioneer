import '../../../core/models/user_account.dart';

abstract interface class AuthService {
  Stream<UserAccount?> watchCurrentUser();
  Future<UserAccount> signInWithGoogle();
  Future<void> signOut();
}
