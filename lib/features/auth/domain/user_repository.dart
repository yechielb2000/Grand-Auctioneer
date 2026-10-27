import '../../../core/models/user_account.dart';

abstract interface class UserRepository {
  Future<UserAccount?> getById(String uid);
  Future<UserAccount> getOrCreate(UserAccount account);
  Future<void> save(UserAccount account);
  Future<void> saveMessagingToken(String uid, String token);
}
