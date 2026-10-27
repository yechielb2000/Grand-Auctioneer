import '../../../core/models/auction.dart';

abstract interface class AuctionRepository {
  Stream<List<Auction>> watchActive();
  Future<void> create(Auction auction);
  Future<void> placeBid({
    required String auctionId,
    required String bidderId,
    required double amount,
  });
  Future<void> settleEnglishAuction(String auctionId);
  Future<void> claimDutchAuction({
    required String auctionId,
    required String bidderId,
  });
}
