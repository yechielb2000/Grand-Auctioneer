import '../../../core/models/asset_item.dart';

abstract interface class AssetRepository {
  Stream<List<AssetItem>> watchByOwner(String ownerId);
  Future<void> save(AssetItem item);
}
