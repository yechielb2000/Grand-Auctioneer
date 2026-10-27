import 'package:auction_empire/core/models/asset_item.dart';
import 'package:auction_empire/core/models/auction.dart';
import 'package:auction_empire/core/models/property.dart';
import 'package:auction_empire/core/models/user_account.dart';
import 'package:auction_empire/core/utils/dutch_auction_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('domain model serialization', () {
    test('round trips a user account', () {
      final account = UserAccount(
        uid: 'user-1',
        displayName: 'Player One',
        email: 'player@example.test',
        photoUrl: '',
        cashBalance: 10000,
        gems: 50,
        netWorth: 12500,
        createdAt: DateTime.utc(2026, 1, 2),
      );

      expect(UserAccount.fromMap(account.toMap()).toMap(), account.toMap());
    });

    test('round trips a grid property and capacity', () {
      final property = Property(
        id: 'property-1',
        ownerId: 'user-1',
        name: 'Studio',
        type: PropertyType.apartment,
        coordinates: PropertyCoordinates.grid(x: 3, y: 7),
        capacity: PropertyCapacity(furnitureSlots: 4, vehicleSlots: 0),
        placedItemIds: ['asset-1'],
        isListedForAuction: false,
      );

      expect(Property.fromMap(property.toMap()).toMap(), property.toMap());
    });

    test('round trips a geolocation property', () {
      const coordinates = PropertyCoordinates.geo(lat: 31.7, lng: 35.2);

      expect(
        PropertyCoordinates.fromMap(coordinates.toMap()).toMap(),
        coordinates.toMap(),
      );
    });

    test('round trips an asset with no property placement', () {
      const asset = AssetItem(
        id: 'asset-1',
        ownerId: 'user-1',
        name: 'Velvet Sofa',
        category: AssetCategory.furniture,
        rarity: AssetRarity.rare,
        estimatedValue: 1850,
        currentLocationPropertyId: null,
        iconPath: 'assets/icons/sofa.png',
      );

      expect(AssetItem.fromMap(asset.toMap()).toMap(), asset.toMap());
    });

    test('round trips an auction and checks status at a supplied time', () {
      final auction = Auction(
        id: 'auction-1',
        sellerId: 'seller-1',
        itemId: 'asset-1',
        propertyId: null,
        auctionType: AuctionType.english,
        startingPrice: 100,
        currentHighestBid: 100,
        highestBidderId: null,
        startTime: DateTime.utc(2026, 1, 2),
        endTime: DateTime.utc(2026, 1, 2, 1),
        status: AuctionStatus.active,
      );

      expect(Auction.fromMap(auction.toMap()).toMap(), auction.toMap());
      expect(auction.isActiveAt(DateTime.utc(2026, 1, 2, 0, 30)), isTrue);
      expect(auction.isActiveAt(DateTime.utc(2026, 1, 2, 1)), isFalse);
    });

    test('rejects unknown enum values instead of silently defaulting', () {
      expect(
        () => AssetItem.fromMap({
          'id': 'asset-1',
          'ownerId': 'user-1',
          'name': 'Unknown',
          'category': 'not-a-category',
          'rarity': 'rare',
          'estimatedValue': 5,
          'currentLocationPropertyId': null,
          'iconPath': '',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Dutch auction pricing', () {
    final start = DateTime.utc(2026, 1, 1);

    test('uses the stored start time to calculate a stable price', () {
      final current = start.add(const Duration(seconds: 60));

      expect(
        dutchAuctionPrice(
          startingPrice: 1000,
          startTime: start,
          currentTime: current,
        ),
        940,
      );
      expect(
        dutchAuctionPrice(
          startingPrice: 1000,
          startTime: start,
          currentTime: current,
        ),
        940,
      );
    });

    test('never drops below half the starting price', () {
      expect(
        dutchAuctionPrice(
          startingPrice: 100,
          startTime: start,
          currentTime: start.add(const Duration(hours: 1)),
        ),
        50,
      );
    });
  });
}
