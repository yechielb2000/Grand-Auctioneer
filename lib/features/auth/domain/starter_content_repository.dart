/// Provisions the fixed starter game content for an authenticated account.
abstract interface class StarterContentRepository {
  Future<void> provisionFor(String uid);
}
