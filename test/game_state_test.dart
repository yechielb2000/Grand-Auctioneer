import 'package:auction_empire/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState', () {
    test('starts with the starter balance and three starter items', () {
      final game = GameState();
      expect(game.cash, 10000);
      expect(game.diamonds, 50);
      expect(game.inventory, hasLength(3));
      game.dispose();
    });

    test('fills furniture and vehicle slots independently', () {
      final game = GameState();
      final items = game.inventory;
      final extraFurniture = GameItem(
        name: 'Extra chair',
        category: 'Furniture',
        rarity: 'Common',
        value: 100,
        icon: Icons.chair,
      );
      game.inventory.add(extraFurniture);

      expect(game.placeItem(items[0]), isTrue);
      expect(game.placeItem(items[1]), isTrue);
      expect(game.placeItem(items[2]), isTrue);
      expect(game.placeItem(extraFurniture), isFalse);
      expect(game.removeItemFromProperty(items[0]), isTrue);
      expect(game.placeItem(extraFurniture), isTrue);
      expect(game.placedFurnitureCount, 2);
      expect(game.placedVehicleCount, 1);
      game.dispose();
    });

    test('quick-selling removes the item and grants 65 percent of its value', () {
      final game = GameState();
      final item = game.inventory.first;

      expect(game.quickSell(item), isTrue);
      expect(game.cash, 10000 + (item.value * 0.65).round());
      expect(game.inventory, isNot(contains(item)));
      expect(game.quickSell(item), isFalse);
      game.dispose();
    });

    test('enforces minimum bids and permits one valid sealed bid', () {
      final game = GameState();
      final auction = game.auctions.singleWhere((a) => a.mode == AuctionMode.sealedBid);

      expect(game.placeBid(auction, auction.startingPrice - 1), isFalse);
      expect(game.placeBid(auction, auction.startingPrice), isTrue);
      expect(game.placeBid(auction, auction.startingPrice + 1), isFalse);
      expect(auction.bids, 7);
      game.dispose();
    });

    test('extends an English auction by 15 seconds for a last-moment bid', () {
      final game = GameState();
      final auction = GameAuction(
        itemName: 'Test item',
        icon: game.inventory.first.icon,
        mode: AuctionMode.english,
        startingPrice: 100,
        currentBid: 100,
        endsAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      final originalEnd = auction.endsAt;

      expect(game.placeBid(auction, 105), isTrue);
      expect(auction.endsAt.difference(originalEnd).inSeconds, 15);
      game.dispose();
    });

    test('Dutch purchase charges the displayed price and transfers the item', () {
      final game = GameState();
      final auction = game.auctions.singleWhere((a) => a.mode == AuctionMode.dutch);
      game.cash = 50000;
      final price = auction.currentPrice;

      expect(game.claimDutchAuction(auction), isTrue);
      expect(game.cash, 50000 - price);
      expect(game.inventory.last.name, auction.itemName);
      expect(game.auctions, isNot(contains(auction)));
      game.dispose();
    });

    test('caps voluntary reward claims at five per session', () {
      final game = GameState();

      for (var i = 0; i < 5; i++) {
        expect(game.claimReward('cash-$i', cashReward: 2500), isTrue);
      }
      expect(game.claimReward('cash-5', cashReward: 2500), isFalse);
      expect(game.cash, 22500);
      game.dispose();
    });

    test('uses the configured daily reward claim limit', () {
      final game = GameState(dailyRewardLimit: 2);

      expect(game.claimReward('cash-1', cashReward: 2500), isTrue);
      expect(game.claimReward('cash-2', cashReward: 2500), isTrue);
      expect(game.claimReward('cash-3', cashReward: 2500), isFalse);
      game.dispose();
    });

    test('uses the configured English auction anti-sniping extension', () {
      final game = GameState(
        auctionExtension: const Duration(seconds: 30),
      );
      final auction = GameAuction(
        itemName: 'Test item',
        icon: game.inventory.first.icon,
        mode: AuctionMode.english,
        startingPrice: 100,
        currentBid: 100,
        endsAt: DateTime.now().add(const Duration(seconds: 20)),
      );
      final originalEnd = auction.endsAt;

      expect(game.placeBid(auction, 105), isTrue);
      expect(auction.endsAt.difference(originalEnd).inSeconds, 30);
      game.dispose();
    });

    test('creates an auction with the selected mode and duration', () {
      final game = GameState();
      final item = game.inventory.first;

      expect(
        game.createListing(
          item,
          AuctionMode.vickrey,
          3000,
          duration: const Duration(hours: 6),
        ),
        isTrue,
      );
      final listing = game.auctions.first;
      expect(listing.mode, AuctionMode.vickrey);
      expect(listing.endsAt.difference(listing.startsAt).inHours, 6);
      expect(game.inventory, isNot(contains(item)));
      game.dispose();
    });

    test('keeps sealed bids private until expiry and settles a Vickrey win', () {
      final game = GameState();
      final auction = GameAuction(
        itemName: 'Sealed test item',
        icon: Icons.palette,
        mode: AuctionMode.vickrey,
        startingPrice: 100,
        endsAt: DateTime.now().add(const Duration(minutes: 1)),
        demoCompetingBids: [125, 140],
      );
      game.auctions.add(auction);

      expect(game.placeBid(auction, 160), isTrue);
      expect(auction.revealedBids, isNull);
      expect(game.cash, 10000);

      auction.endsAt = DateTime.now().subtract(const Duration(seconds: 1));
      expect(game.resolveExpiredAuctions(), isTrue);
      expect(auction.revealedBids, [125, 140, 160]);
      expect(auction.playerWon, isTrue);
      expect(auction.clearingPrice, 141);
      expect(game.cash, 9859);
      expect(game.inventory.last.name, 'Sealed test item');
      game.dispose();
    });

    test('returns an unsold property listing when it expires', () {
      final game = GameState();
      final property = game.properties.single;

      expect(
        game.createPropertyListing(
          property,
          AuctionMode.english,
          15000,
          duration: const Duration(minutes: 1),
        ),
        isTrue,
      );
      expect(game.properties, isEmpty);

      final listing = game.auctions.first;
      listing.endsAt = DateTime.now().subtract(const Duration(seconds: 1));
      expect(game.resolveExpiredAuctions(), isTrue);
      expect(game.properties.single, same(property));
      expect(listing.resolved, isTrue);
      game.dispose();
    });

    test('allows raising an English bid without reserving the same cash twice', () {
      final game = GameState();
      final auction = GameAuction(
        itemName: 'Rising test item',
        icon: Icons.directions_car,
        mode: AuctionMode.english,
        startingPrice: 100,
        currentBid: 100,
        endsAt: DateTime.now().add(const Duration(minutes: 1)),
      );
      game.auctions.add(auction);

      expect(game.placeBid(auction, 105), isTrue);
      expect(game.availableCash, 9895);
      expect(game.placeBid(auction, 111), isTrue);
      expect(game.availableCash, 9889);
      expect(game.placeBid(auction, 10000), isFalse);
      game.dispose();
    });
  });
}
