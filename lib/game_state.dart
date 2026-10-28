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

class GameProperty {
  const GameProperty({
    required this.id,
    required this.name,
    required this.value,
    required this.furnitureSlots,
    required this.vehicleSlots,
  });

  final String id;
  final String name;
  final int value;
  final int furnitureSlots;
  final int vehicleSlots;
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
    List<int> demoCompetingBids = const [],
    this.listedItem,
    this.listedProperty,
    this.isPlayerListing = false,
  })  : startsAt = startsAt ?? DateTime.now(),
        _demoCompetingBids = List.unmodifiable(demoCompetingBids);

  final String itemName;
  final IconData icon;
  final AuctionMode mode;
  final int startingPrice;
  final DateTime startsAt;
  DateTime endsAt;
  int? currentBid;
  int bids;
  int? myBid;
  final List<int> _demoCompetingBids;
  final GameItem? listedItem;
  final GameProperty? listedProperty;
  final bool isPlayerListing;
  bool resolved = false;
  bool? playerWon;
  int? winningBid;
  int? clearingPrice;
  List<int>? _revealedBids;

  bool get isExpired => !DateTime.now().isBefore(endsAt);

  List<int>? get revealedBids =>
      resolved ? List.unmodifiable(_revealedBids ?? const []) : null;

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
            demoCompetingBids: [5600, 6200, 7100],
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
            demoCompetingBids: [1950, 2200, 2600],
            endsAt: DateTime.now().add(const Duration(minutes: 15)),
          ),
        ],
        properties = [
          const GameProperty(
            id: 'starter-shed',
            name: 'Starter Shed',
            value: 15000,
            furnitureSlots: 2,
            vehicleSlots: 1,
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
  final List<GameProperty> properties;
  final Set<String> claimedRewards = {};

  int get netWorth =>
      cash +
      diamonds * 100 +
      inventory.fold(0, (total, item) => total + item.value) +
      properties.fold(0, (total, property) => total + property.value) +
      auctions.fold(
        0,
        (total, auction) =>
            total +
            (auction.isPlayerListing && !auction.resolved
                ? (auction.listedItem?.value ?? auction.listedProperty?.value ?? 0)
                : 0),
      );

  int get placedCount => inventory.where((item) => item.placed).length;
  int get placedFurnitureCount => inventory
      .where((item) => item.placed && !_isVehicle(item))
      .length;
  int get placedVehicleCount =>
      inventory.where((item) => item.placed && _isVehicle(item)).length;
  int get availableCash =>
      cash -
      auctions
          .where((auction) => !auction.resolved && auction.myBid != null)
          .fold(0, (total, auction) => total + auction.myBid!);

  bool placeItem(GameItem item) {
    if (!inventory.contains(item) || item.placed || properties.isEmpty) {
      return false;
    }
    final property = properties.first;
    if (_isVehicle(item)
        ? placedVehicleCount >= property.vehicleSlots
        : placedFurnitureCount >= property.furnitureSlots) {
      return false;
    }
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
        auction.resolved ||
        auction.isPlayerListing ||
        auction.mode == AuctionMode.dutch ||
        (auction.mode != AuctionMode.english && auction.myBid != null) ||
        amount < auction.startingPrice ||
        amount >
            cash -
                auctions
                    .where((other) =>
                        !identical(other, auction) &&
                        !other.resolved &&
                        other.myBid != null)
                    .fold(0, (total, other) => total + other.myBid!)) {
      return false;
    }
    if (auction.mode == AuctionMode.english &&
        auction.currentBid != null &&
        amount < auction.currentBid! * 1.05) {
      return false;
    }
    if (auction.mode == AuctionMode.english &&
        auction.endsAt.difference(DateTime.now()) <= auctionExtension) {
      auction.endsAt = auction.endsAt.add(auctionExtension);
    }
    auction.myBid = amount;
    if (auction.mode == AuctionMode.english) auction.currentBid = amount;
    auction.bids++;
    notifyListeners();
    return true;
  }

  bool claimDutchAuction(GameAuction auction) {
    final price = auction.currentPrice;
    if (auction.mode != AuctionMode.dutch ||
        auction.isExpired ||
        auction.resolved ||
        auction.isPlayerListing ||
        availableCash < price) {
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

  bool resolveExpiredAuctions() {
    var changed = false;
    for (final auction in auctions) {
      if (auction.resolved || !auction.isExpired) continue;

      auction.resolved = true;
      if (auction.mode == AuctionMode.dutch) {
        auction.playerWon = false;
        changed = true;
        continue;
      }

      if (auction.mode == AuctionMode.english) {
        auction.winningBid = auction.currentBid;
        auction.clearingPrice = auction.currentBid;
        auction.playerWon = auction.myBid != null;
      } else {
        final bids = [...auction._demoCompetingBids];
        if (auction.myBid != null) bids.add(auction.myBid!);
        bids.sort();
        auction._revealedBids = bids;
        auction.winningBid = bids.isEmpty ? null : bids.last;
        final highestCompetitorBid = auction._demoCompetingBids.isEmpty
            ? null
            : auction._demoCompetingBids.reduce((a, b) => a > b ? a : b);
        auction.playerWon = auction.myBid != null &&
            (highestCompetitorBid == null ||
                auction.myBid! > highestCompetitorBid);
        if (auction.playerWon == true) {
          final secondHighestBid = bids.length < 2 ? 0 : bids[bids.length - 2];
          auction.clearingPrice = auction.mode == AuctionMode.vickrey
              ? (secondHighestBid + 1)
                  .clamp(auction.startingPrice, auction.myBid!)
                  .toInt()
              : auction.myBid;
        } else {
          auction.clearingPrice = auction.winningBid;
        }
      }

      if (auction.playerWon == true && auction.clearingPrice != null) {
        final price = auction.clearingPrice!;
        cash -= price;
        if (auction.listedItem != null) {
          inventory.add(auction.listedItem!);
        } else if (auction.listedProperty != null) {
          properties.add(auction.listedProperty!);
        } else {
          inventory.add(
            GameItem(
              name: auction.itemName,
              category: 'Auction win',
              rarity: 'Rare',
              value: price,
              icon: auction.icon,
            ),
          );
        }
      } else if (auction.isPlayerListing) {
        if (auction.listedItem != null) inventory.add(auction.listedItem!);
        if (auction.listedProperty != null) {
          properties.add(auction.listedProperty!);
        }
      }
      changed = true;
    }
    if (changed) notifyListeners();
    return changed;
  }

  bool createListing(
    GameItem item,
    AuctionMode mode,
    int askingPrice, {
    Duration duration = const Duration(hours: 1),
  }) {
    if (!inventory.contains(item) ||
        item.placed ||
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
        listedItem: item,
        isPlayerListing: true,
      ),
    );
    listingsToday++;
    notifyListeners();
    return true;
  }

  bool createPropertyListing(
    GameProperty property,
    AuctionMode mode,
    int askingPrice, {
    Duration duration = const Duration(hours: 1),
  }) {
    if (!properties.contains(property) ||
        placedCount > 0 ||
        askingPrice <= 0 ||
        duration <= Duration.zero) {
      return false;
    }
    properties.remove(property);
    auctions.insert(
      0,
      GameAuction(
        itemName: property.name,
        icon: Icons.home_work_rounded,
        mode: mode,
        startingPrice: askingPrice,
        endsAt: DateTime.now().add(duration),
        listedProperty: property,
        isPlayerListing: true,
      ),
    );
    listingsToday++;
    notifyListeners();
    return true;
  }

  bool collectRent() {
    if (rent <= 0 || properties.isEmpty) return false;
    cash += rent;
    notifyListeners();
    return true;
  }

  bool claimRentReward() {
    if (claimedRewards.contains('rent') ||
        rent <= 0 ||
        properties.isEmpty) {
      return false;
    }
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

  static bool _isVehicle(GameItem item) =>
      item.category == 'Vehicles' || item.category == 'Boats';
}
