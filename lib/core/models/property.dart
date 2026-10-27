import 'model_serialization.dart';

enum PropertyType { shed, apartment, villa, warehouse, marina, showroom }

class PropertyCoordinates {
  const PropertyCoordinates.geo({required this.lat, required this.lng})
      : x = null,
        y = null;
  const PropertyCoordinates.grid({required this.x, required this.y})
      : lat = null,
        lng = null;

  final double? lat;
  final double? lng;
  final int? x;
  final int? y;

  factory PropertyCoordinates.fromMap(Map<String, dynamic> map) {
    if (map['lat'] is num && map['lng'] is num) {
      return PropertyCoordinates.geo(
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      );
    }
    if (map['x'] is int && map['y'] is int) {
      return PropertyCoordinates.grid(x: map['x'] as int, y: map['y'] as int);
    }
    throw const FormatException('Coordinates must contain lat/lng or x/y.');
  }

  Map<String, dynamic> toMap() => lat != null
      ? {'lat': lat, 'lng': lng}
      : {'x': x, 'y': y};
}

class PropertyCapacity {
  const PropertyCapacity({
    required this.furnitureSlots,
    required this.vehicleSlots,
  });

  final int furnitureSlots;
  final int vehicleSlots;

  factory PropertyCapacity.fromMap(Map<String, dynamic> map) =>
      PropertyCapacity(
        furnitureSlots: intFromMap(map, 'furnitureSlots'),
        vehicleSlots: intFromMap(map, 'vehicleSlots'),
      );

  Map<String, dynamic> toMap() => {
        'furnitureSlots': furnitureSlots,
        'vehicleSlots': vehicleSlots,
      };
}

class Property {
  Property({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.coordinates,
    required this.capacity,
    required List<String> placedItemIds,
    required this.isListedForAuction,
  }) : placedItemIds = List.unmodifiable(placedItemIds);

  final String id;
  final String ownerId;
  final String name;
  final PropertyType type;
  final PropertyCoordinates coordinates;
  final PropertyCapacity capacity;
  final List<String> placedItemIds;
  final bool isListedForAuction;

  factory Property.fromMap(Map<String, dynamic> map) => Property(
        id: map['id'] as String,
        ownerId: map['ownerId'] as String,
        name: map['name'] as String,
        type: enumFromName(PropertyType.values, map['type'], 'property type'),
        coordinates: PropertyCoordinates.fromMap(
          Map<String, dynamic>.from(map['coordinates'] as Map),
        ),
        capacity: PropertyCapacity.fromMap(
          Map<String, dynamic>.from(map['capacity'] as Map),
        ),
        placedItemIds: List<String>.from(map['placedItemIds'] as List),
        isListedForAuction: map['isListedForAuction'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'type': type.name,
        'coordinates': coordinates.toMap(),
        'capacity': capacity.toMap(),
        'placedItemIds': placedItemIds,
        'isListedForAuction': isListedForAuction,
      };
}
