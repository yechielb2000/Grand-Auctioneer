import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/asset_item.dart';
import '../../core/models/auction.dart';
import '../../core/models/model_serialization.dart';
import '../../core/models/property.dart';
import '../../core/models/user_account.dart';
import '../../core/utils/dutch_auction_price.dart';
import '../../features/auth/domain/user_repository.dart';
import '../../features/auction/domain/auction_repository.dart';
import '../../features/inventory/domain/asset_repository.dart';
import '../../features/map_properties/domain/property_repository.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<UserAccount?> getById(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    return data == null ? null : UserAccount.fromMap(_decodeMap(data));
  }

  @override
  Future<UserAccount> getOrCreate(UserAccount account) async {
    final reference = _users.doc(account.uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data != null) {
        return UserAccount.fromMap(_decodeMap(data));
      }

      final initialData = account.toMap()
        ..['createdAt'] = Timestamp.fromDate(account.createdAt);
      transaction.set(reference, initialData);
      return account;
    });
  }

  @override
  Future<void> save(UserAccount account) async {
    final data = account.toMap()..['createdAt'] = Timestamp.fromDate(account.createdAt);
    await _users.doc(account.uid).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> saveMessagingToken(String uid, String token) =>
      _users.doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
}

class FirestorePropertyRepository implements PropertyRepository {
  FirestorePropertyRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Property>> watchByOwner(String ownerId) => _firestore
      .collection('properties')
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Property.fromMap({...doc.data(), 'id': doc.id}))
          .toList(growable: false));

  @override
  Future<void> save(Property property) => _firestore
      .collection('properties')
      .doc(property.id)
      .set(property.toMap(), SetOptions(merge: true));
}

class FirestoreAssetRepository implements AssetRepository {
  FirestoreAssetRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AssetItem>> watchByOwner(String ownerId) => _firestore
      .collection('assets')
      .where('ownerId', isEqualTo: ownerId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AssetItem.fromMap({...doc.data(), 'id': doc.id}))
          .toList(growable: false));

  @override
  Future<void> save(AssetItem item) => _firestore
      .collection('assets')
      .doc(item.id)
      .set(item.toMap(), SetOptions(merge: true));
}

class FirestoreAuctionRepository implements AuctionRepository {
  FirestoreAuctionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _auctions =>
      _firestore.collection('auctions');

  @override
  Stream<List<Auction>> watchActive() => _auctions
      .where('status', isEqualTo: AuctionStatus.active.name)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Auction.fromMap(_decodeMap({...doc.data(), 'id': doc.id})))
          .toList(growable: false));

  @override
  Future<void> create(Auction auction) {
    if (!auction.startingPrice.isFinite ||
        auction.startingPrice <= 0 ||
        !auction.endTime.isAfter(auction.startTime)) {
      throw ArgumentError('Auction prices and times must be valid.');
    }
    final data = auction.toMap()
      ..['startTime'] = Timestamp.fromDate(auction.startTime)
      ..['endTime'] = Timestamp.fromDate(auction.endTime)
      ..['bidderIds'] = <String>[];
    return _auctions.doc(auction.id).set(data);
  }

  @override
  Future<void> placeBid({
    required String auctionId,
    required String bidderId,
    required double amount,
  }) async {
    final auctionRef = _auctions.doc(auctionId);
    final userRef = _firestore.collection('users').doc(bidderId);

    await _firestore.runTransaction((transaction) async {
      final auctionSnapshot = await transaction.get(auctionRef);
      final userSnapshot = await transaction.get(userRef);
      final auction = auctionSnapshot.data();
      final user = userSnapshot.data();
      if (auction == null || user == null) {
        throw StateError('Auction or bidder account does not exist.');
      }

      final startTime = _asDateTime(auction['startTime']);
      final endTime = _asDateTime(auction['endTime']);
      final now = DateTime.now();
      final type = enumFromName(AuctionType.values, auction['auctionType'], 'auction type');
      final currentBid = (auction['currentHighestBid'] as num).toDouble();
      final startingPrice = (auction['startingPrice'] as num).toDouble();
      final cashBalance = (user['cashBalance'] as num).toDouble();
      final reservedBalance = (user['reservedBalance'] as num?)?.toDouble() ?? 0;
      final bidderIds = List<String>.from(auction['bidderIds'] as List? ?? const []);
      final previousBidderId = auction['highestBidderId'] as String?;
      final previousBidderRef = previousBidderId == null
          ? null
          : _firestore.collection('users').doc(previousBidderId);
      final previousBidderSnapshot = previousBidderRef == null
          ? null
          : await transaction.get(previousBidderRef);
      final previousBidder = previousBidderSnapshot?.data();

      if (auction['status'] != AuctionStatus.active.name ||
          now.isBefore(startTime) ||
          !now.isBefore(endTime) ||
          auction['sellerId'] == bidderId ||
          type == AuctionType.dutch ||
          type == AuctionType.blind ||
          type == AuctionType.vickrey ||
          bidderIds.contains(bidderId) ||
          !amount.isFinite ||
          amount < startingPrice ||
          amount > cashBalance - reservedBalance ||
          (type == AuctionType.english && amount < currentBid * 1.05)) {
        throw StateError(
          'Bid is invalid, unsupported for this auction type, or the auction is no longer active.',
        );
      }

      final updates = <String, Object>{
        'currentHighestBid': amount,
        'highestBidderId': bidderId,
        'bidderIds': [...bidderIds, bidderId],
      };
      final remaining = endTime.difference(now);
      if (type == AuctionType.english &&
          remaining <= const Duration(seconds: 15)) {
        updates['endTime'] = Timestamp.fromDate(
          endTime.add(const Duration(seconds: 15)),
        );
      }
      transaction.update(auctionRef, updates);
      transaction.update(userRef, {'reservedBalance': reservedBalance + amount});
      if (previousBidderId != null) {
        if (previousBidder == null) {
          throw StateError('Previous bidder account does not exist.');
        }
        final previousReserved =
            (previousBidder['reservedBalance'] as num?)?.toDouble() ?? 0;
        if (previousReserved < currentBid) {
          throw StateError('Previous bidder escrow balance is inconsistent.');
        }
        transaction.update(previousBidderRef!, {
          'reservedBalance': previousReserved - currentBid,
        });
      }
    });
  }

  @override
  Future<void> settleEnglishAuction(String auctionId) async {
    final auctionRef = _auctions.doc(auctionId);

    await _firestore.runTransaction((transaction) async {
      final auctionSnapshot = await transaction.get(auctionRef);
      final auction = auctionSnapshot.data();
      if (auction == null) throw StateError('Auction does not exist.');
      final endTime = _asDateTime(auction['endTime']);
      if (auction['status'] != AuctionStatus.active.name ||
          auction['auctionType'] != AuctionType.english.name ||
          DateTime.now().isBefore(endTime)) {
        throw StateError('Auction cannot be settled yet.');
      }

      final bidderId = auction['highestBidderId'] as String?;
      if (bidderId == null) {
        transaction.update(auctionRef, {'status': AuctionStatus.completed.name});
        return;
      }

      final sellerId = auction['sellerId'] as String;
      final itemRef = _firestore.collection('assets').doc(auction['itemId'] as String);
      final bidderRef = _firestore.collection('users').doc(bidderId);
      final sellerRef = _firestore.collection('users').doc(sellerId);
      final itemSnapshot = await transaction.get(itemRef);
      final bidderSnapshot = await transaction.get(bidderRef);
      final sellerSnapshot = await transaction.get(sellerRef);
      final item = itemSnapshot.data();
      final bidder = bidderSnapshot.data();
      final seller = sellerSnapshot.data();
      if (item == null || bidder == null || seller == null) {
        throw StateError('Auction asset, seller, or winning bidder is missing.');
      }

      final price = (auction['currentHighestBid'] as num).toDouble();
      final reservedBalance =
          (bidder['reservedBalance'] as num?)?.toDouble() ?? 0;
      final bidderIds = List<String>.from(auction['bidderIds'] as List? ?? const []);
      final itemValue = (item['estimatedValue'] as num).toDouble();
      if (bidderId == sellerId ||
          item['ownerId'] != sellerId ||
          !bidderIds.contains(bidderId) ||
          reservedBalance < price ||
          (bidder['cashBalance'] as num).toDouble() < price) {
        throw StateError('Auction settlement data is inconsistent.');
      }

      transaction.update(bidderRef, {
        'cashBalance': (bidder['cashBalance'] as num).toDouble() - price,
        'reservedBalance': reservedBalance - price,
        'netWorth': (bidder['netWorth'] as num).toDouble() - price + itemValue,
      });
      transaction.update(sellerRef, {
        'cashBalance': (seller['cashBalance'] as num).toDouble() + price,
        'netWorth': (seller['netWorth'] as num).toDouble() + price - itemValue,
      });
      transaction.update(itemRef, {'ownerId': bidderId});
      transaction.update(auctionRef, {'status': AuctionStatus.completed.name});
    });
  }

  @override
  Future<void> claimDutchAuction({
    required String auctionId,
    required String bidderId,
  }) async {
    final auctionRef = _auctions.doc(auctionId);
    final userRef = _firestore.collection('users').doc(bidderId);

    await _firestore.runTransaction((transaction) async {
      final auctionSnapshot = await transaction.get(auctionRef);
      final auction = auctionSnapshot.data();
      if (auction == null) throw StateError('Auction does not exist.');
      final itemRef = _firestore.collection('assets').doc(auction['itemId'] as String);
      final sellerRef = _firestore
          .collection('users')
          .doc(auction['sellerId'] as String);
      final itemSnapshot = await transaction.get(itemRef);
      final userSnapshot = await transaction.get(userRef);
      final sellerSnapshot = await transaction.get(sellerRef);
      final item = itemSnapshot.data();
      final user = userSnapshot.data();
      final seller = sellerSnapshot.data();
      if (item == null || user == null || seller == null) {
        throw StateError(
          'Auction asset, seller, or bidder account does not exist.',
        );
      }

      final startTime = _asDateTime(auction['startTime']);
      final endTime = _asDateTime(auction['endTime']);
      final currentTime = DateTime.now();
      final durationSeconds = endTime.difference(startTime).inSeconds;
      final startingPrice = (auction['startingPrice'] as num).toDouble();
      final price = dutchAuctionPrice(
        startingPrice: startingPrice,
        startTime: startTime,
        currentTime: currentTime,
      );
      final balance = (user['cashBalance'] as num).toDouble();
      final sellerBalance = (seller['cashBalance'] as num).toDouble();
      final itemValue = (item['estimatedValue'] as num).toDouble();

      if (auction['status'] != AuctionStatus.active.name ||
          auction['auctionType'] != AuctionType.dutch.name ||
          auction['sellerId'] == bidderId ||
          currentTime.isBefore(startTime) ||
          !currentTime.isBefore(endTime) ||
          durationSeconds <= 0 ||
          item['ownerId'] != auction['sellerId'] ||
          balance - ((user['reservedBalance'] as num?)?.toDouble() ?? 0) <
              price) {
        throw StateError('Dutch auction claim is invalid or no longer available.');
      }

      transaction.update(userRef, {
        'cashBalance': balance - price,
        'reservedBalance':
            (user['reservedBalance'] as num?)?.toDouble() ?? 0,
        'netWorth': (user['netWorth'] as num).toDouble() - price + itemValue,
      });
      transaction.update(sellerRef, {
        'cashBalance': sellerBalance + price,
        'netWorth': (seller['netWorth'] as num).toDouble() + price - itemValue,
      });
      transaction.update(itemRef, {'ownerId': bidderId});
      transaction.update(auctionRef, {
        'currentHighestBid': price,
        'highestBidderId': bidderId,
        'status': AuctionStatus.completed.name,
      });
    });
  }
}

Map<String, dynamic> _decodeMap(Map<String, dynamic> map) => map.map(
      (key, value) => MapEntry(
        key,
        value is Timestamp ? value.toDate().toUtc().toIso8601String() : value,
      ),
    );

DateTime _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Expected timestamp, got $value.');
}
