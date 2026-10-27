import 'model_serialization.dart';

enum AuctionType { english, dutch, blind, vickrey }

enum AuctionStatus { active, completed, cancelled }

class Auction {
  const Auction({
    required this.id,
    required this.sellerId,
    required this.itemId,
    required this.propertyId,
    required this.auctionType,
    required this.startingPrice,
    required this.currentHighestBid,
    required this.highestBidderId,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  final String id;
  final String sellerId;
  final String itemId;
  final String? propertyId;
  final AuctionType auctionType;
  final double startingPrice;
  final double currentHighestBid;
  final String? highestBidderId;
  final DateTime startTime;
  final DateTime endTime;
  final AuctionStatus status;

  bool isActiveAt(DateTime now) =>
      status == AuctionStatus.active && now.isBefore(endTime);

  factory Auction.fromMap(Map<String, dynamic> map) => Auction(
        id: map['id'] as String,
        sellerId: map['sellerId'] as String,
        itemId: map['itemId'] as String,
        propertyId: map['propertyId'] as String?,
        auctionType: enumFromName(AuctionType.values, map['auctionType'], 'auction type'),
        startingPrice: doubleFromMap(map, 'startingPrice'),
        currentHighestBid: doubleFromMap(map, 'currentHighestBid'),
        highestBidderId: map['highestBidderId'] as String?,
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: DateTime.parse(map['endTime'] as String),
        status: enumFromName(AuctionStatus.values, map['status'], 'auction status'),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sellerId': sellerId,
        'itemId': itemId,
        'propertyId': propertyId,
        'auctionType': auctionType.name,
        'startingPrice': startingPrice,
        'currentHighestBid': currentHighestBid,
        'highestBidderId': highestBidderId,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'status': status.name,
      };
}
