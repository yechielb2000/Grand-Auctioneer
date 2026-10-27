import 'model_serialization.dart';

enum AssetCategory { furniture, vehicle, boat, decoration, collectible }

enum AssetRarity { common, rare, epic, legendary }

class AssetItem {
  const AssetItem({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.rarity,
    required this.estimatedValue,
    required this.currentLocationPropertyId,
    required this.iconPath,
  });

  final String id;
  final String ownerId;
  final String name;
  final AssetCategory category;
  final AssetRarity rarity;
  final double estimatedValue;
  final String? currentLocationPropertyId;
  final String iconPath;

  factory AssetItem.fromMap(Map<String, dynamic> map) => AssetItem(
        id: map['id'] as String,
        ownerId: map['ownerId'] as String,
        name: map['name'] as String,
        category: enumFromName(AssetCategory.values, map['category'], 'asset category'),
        rarity: enumFromName(AssetRarity.values, map['rarity'], 'asset rarity'),
        estimatedValue: doubleFromMap(map, 'estimatedValue'),
        currentLocationPropertyId: map['currentLocationPropertyId'] as String?,
        iconPath: map['iconPath'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'category': category.name,
        'rarity': rarity.name,
        'estimatedValue': estimatedValue,
        'currentLocationPropertyId': currentLocationPropertyId,
        'iconPath': iconPath,
      };
}
