import 'model_serialization.dart';

class UserAccount {
  const UserAccount({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.cashBalance,
    this.reservedBalance = 0,
    required this.gems,
    required this.netWorth,
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final double cashBalance;
  final double reservedBalance;
  final int gems;
  final double netWorth;
  final DateTime createdAt;

  factory UserAccount.fromMap(Map<String, dynamic> map) => UserAccount(
        uid: map['uid'] as String,
        displayName: map['displayName'] as String,
        email: map['email'] as String,
        photoUrl: map['photoUrl'] as String? ?? '',
        cashBalance: doubleFromMap(map, 'cashBalance'),
        reservedBalance: map['reservedBalance'] == null
            ? 0
            : doubleFromMap(map, 'reservedBalance'),
        gems: intFromMap(map, 'gems'),
        netWorth: doubleFromMap(map, 'netWorth'),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'cashBalance': cashBalance,
        'reservedBalance': reservedBalance,
        'gems': gems,
        'netWorth': netWorth,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}
