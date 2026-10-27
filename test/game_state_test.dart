import 'package:auction_empire/game_state.dart';
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

    test('limits property placement and allows removing an item', () {
      final game = GameState();
      final items = game.inventory;

      expect(game.placeItem(items[0]), isTrue);
      expect(game.placeItem(items[1]), isTrue);
      expect(game.placeItem(items[2]), isFalse);
      expect(game.removeItemFromProperty(items[0]), isTrue);
      expect(game.placeItem(items[2]), isTrue);
      expect(game.placedCount, 2);
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
  });
}
