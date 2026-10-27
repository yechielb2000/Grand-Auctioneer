import '../../../core/models/property.dart';

abstract interface class PropertyRepository {
  Stream<List<Property>> watchByOwner(String ownerId);
  Future<void> save(Property property);
}
