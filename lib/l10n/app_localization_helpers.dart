import 'generated/app_localizations.dart';

String localizedCategory(AppLocalizations l10n, String category) =>
    switch (category) {
      'Furniture' => l10n.categoryFurniture,
      'Vehicles' => l10n.categoryVehicles,
      'Collectibles' => l10n.categoryCollectibles,
      'Boats' => l10n.categoryBoats,
      _ => category,
    };

String localizedRarity(AppLocalizations l10n, String rarity) =>
    switch (rarity) {
      'Rare' => l10n.rarityRare,
      'Uncommon' => l10n.rarityUncommon,
      'Epic' => l10n.rarityEpic,
      _ => rarity,
    };

String localizedItemName(AppLocalizations l10n, String name) =>
    switch (name) {
      'Vintage Velvet Sofa' => l10n.vintageSofa,
      'Classic City Scooter' => l10n.cityScooter,
      'Retro Arcade Cabinet' => l10n.arcadeCabinet,
      'Midnight GT Coupe' => l10n.midnightCoupe,
      'Modernist Penthouse Art' => l10n.penthouseArt,
      'Coastal Speedboat' => l10n.speedboat,
      'Art Deco Wall Clock' => l10n.wallClock,
      _ => name,
    };

String localizedPropertyName(AppLocalizations l10n, String name) =>
    switch (name) {
      'Starter Shed' => l10n.starterShedName,
      _ => name,
    };
