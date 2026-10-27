import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/utils/dutch_auction_price.dart';

enum AuctionMode { english, dutch, sealedBid, vickrey }

extension AuctionModeLabel on AuctionMode {
  String get label => switch (this) {
        AuctionMode.english => 'English',
        AuctionMode.dutch => 'Dutch',
        AuctionMode.sealedBid => 'Sealed bid',
        AuctionMode.vickrey => 'Vickrey',
      };

  String get description => switch (this) {
        AuctionMode.english => 'Open bidding · highest bid wins',
        AuctionMode.dutch => 'Descending price · first to claim wins',
        AuctionMode.sealedBid => 'Hidden bids · winner pays their bid',
        AuctionMode.vickrey => 'Hidden bids · winner pays second-highest + \$1',
      };
}

class GameItem {
  GameItem({
    required this.name,
    required this.category,
    required this.rarity,
    required this.value,
    required this.icon,
    this.placed = false,
  });

  final String name;
  final String category;
  final String rarity;
  final int value;
  final IconData icon;
  bool placed;
}

class GameAuction {
  GameAuction({
    required this.itemName,
    required this.icon,
    required this.mode,
    required this.startingPrice,
    required this.endsAt,
    DateTime? startsAt,
    this.currentBid,
    this.bids = 0,
    this.myBid,
  }) : startsAt = startsAt ?? DateTime.now();

  final String itemName;
  final IconData icon;
  final AuctionMode mode;
  final int startingPrice;
  final DateTime startsAt;
  DateTime endsAt;
  int? currentBid;
  int bids;
  int? myBid;

  bool get isExpired => DateTime.now().isAfter(endsAt);

  int get currentPrice {
    if (mode != AuctionMode.dutch) return currentBid ?? startingPrice;
    return dutchAuctionPrice(
      startingPrice: startingPrice.toDouble(),
      startTime: startsAt,
      currentTime: DateTime.now(),
    ).round();
  }
}

class GameState extends ChangeNotifier {
  GameState({
    this.auctionExtension = const Duration(seconds: 15),
    this.dailyRewardLimit = 5,
  })  : inventory = [
          GameItem(
            name: 'Vintage Velvet Sofa',
            category: 'Furniture',
            rarity: 'Rare',
            value: 1850,
            icon: Icons.weekend_rounded,
          ),
          GameItem(
            name: 'Classic City Scooter',
            category: 'Vehicles',
            rarity: 'Uncommon',
            value: 2400,
            icon: Icons.electric_scooter_rounded,
          ),
          GameItem(
            name: 'Retro Arcade Cabinet',
            category: 'Collectibles',
            rarity: 'Epic',
            value: 3200,
            icon: Icons.sports_esports_rounded,
          ),
        ],
        auctions = [
          GameAuction(
            itemName: 'Midnight GT Coupe',
            icon: Icons.directions_car_rounded,
            mode: AuctionMode.english,
            startingPrice: 12400,
            currentBid: 16800,
            bids: 14,
            endsAt: DateTime.now().add(const Duration(minutes: 8, seconds: 42)),
          ),
          GameAuction(
            itemName: 'Modernist Penthouse Art',
            icon: Icons.palette_rounded,
            mode: AuctionMode.vickrey,
            startingPrice: 5200,
            bids: 9,
            endsAt: DateTime.now().add(const Duration(minutes: 24, seconds: 5)),
          ),
          GameAuction(
            itemName: 'Coastal Speedboat',
            icon: Icons.sailing_rounded,
            mode: AuctionMode.dutch,
            startingPrice: 22000,
            endsAt: DateTime.now().add(const Duration(minutes: 48)),
          ),
          GameAuction(
            itemName: 'Art Deco Wall Clock',
            icon: Icons.access_time_rounded,
            mode: AuctionMode.sealedBid,
            startingPrice: 1800,
            bids: 6,
            endsAt: DateTime.now().add(const Duration(minutes: 15)),
          ),
        ];

  int cash = 10000;
  int diamonds = 50;
  int rent = 420;
  final Duration auctionExtension;
  final int dailyRewardLimit;
  int dailyRewardClaims = 0;
  int listingsToday = 0;
  final List<GameItem> inventory;
  final List<GameAuction> auctions;
  final Set<String> claimedRewards = {};

  int get netWorth =>
      cash + diamonds * 100 + inventory.fold(0, (total, item) => total + item.value);

  int get placedCount => inventory.where((item) => item.placed).length;

  bool placeItem(GameItem item) {
    if (item.placed || placedCount >= 2) return false;
    item.placed = true;
    notifyListeners();
    return true;
  }

  bool removeItemFromProperty(GameItem item) {
    if (!item.placed) return false;
    item.placed = false;
    notifyListeners();
    return true;
  }

  bool quickSell(GameItem item) {
    if (item.placed || !inventory.remove(item)) return false;
    cash += (item.value * 0.65).round();
    notifyListeners();
    return true;
  }

  bool placeBid(GameAuction auction, int amount) {
    if (auction.isExpired ||
        auction.mode == AuctionMode.dutch ||
        auction.myBid != null ||
        amount < auction.startingPrice ||
        amount > cash) {
      return false;
    }
    if (auction.mode == AuctionMode.english &&
        amount < (auction.currentBid ?? auction.startingPrice) * 1.05) {
      return false;
    }
    if (auction.mode == AuctionMode.english &&
        auction.endsAt.difference(DateTime.now()) <= auctionExtension) {
      auction.endsAt = auction.endsAt.add(auctionExtension);
    }
    auction.myBid = amount;
    auction.currentBid = amount;
    auction.bids++;
    notifyListeners();
    return true;
  }

  bool claimDutchAuction(GameAuction auction) {
    final price = auction.currentPrice;
    if (auction.mode != AuctionMode.dutch || auction.isExpired || cash < price) {
      return false;
    }
    cash -= price;
    inventory.add(
      GameItem(
        name: auction.itemName,
        category: 'Auction win',
        rarity: 'Rare',
        value: price,
        icon: auction.icon,
      ),
    );
    auctions.remove(auction);
    notifyListeners();
    return true;
  }

  bool createListing(
    GameItem item,
    AuctionMode mode,
    int askingPrice, {
    Duration duration = const Duration(hours: 1),
  }) {
    if (item.placed ||
        askingPrice <= 0 ||
        duration <= Duration.zero ||
        !inventory.remove(item)) {
      return false;
    }
    auctions.insert(
      0,
      GameAuction(
        itemName: item.name,
        icon: item.icon,
        mode: mode,
        startingPrice: askingPrice,
        endsAt: DateTime.now().add(duration),
      ),
    );
    listingsToday++;
    notifyListeners();
    return true;
  }

  bool collectRent() {
    if (rent <= 0) return false;
    cash += rent;
    notifyListeners();
    return true;
  }

  bool claimRentReward() {
    if (claimedRewards.contains('rent') || rent <= 0) return false;
    claimedRewards.add('rent');
    return collectRent();
  }

  bool claimReward(String id, {required int cashReward, int diamondReward = 0}) {
    if (claimedRewards.contains(id) || dailyRewardClaims >= dailyRewardLimit) return false;
    claimedRewards.add(id);
    dailyRewardClaims++;
    cash += cashReward;
    diamonds += diamondReward;
    notifyListeners();
    return true;
  }
}
