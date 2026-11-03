import 'package:flutter/foundation.dart';

enum AccountRole { customer, creator }

/// The signed-in (local, dummy) user.
@immutable
class Account {
  const Account({required this.name, this.role = AccountRole.customer});

  final String name;
  final AccountRole role;

  bool get isCreator => role == AccountRole.creator;

  Account copyWith({String? name, AccountRole? role}) =>
      Account(name: name ?? this.name, role: role ?? this.role);
}

/// One line of the coin history (`{l, a}` in the artifact).
@immutable
class CoinTx {
  const CoinTx(this.label, this.amount);

  final String label;
  final int amount;
}

/// A coin pack on the wallet screen (`[price, coins, bonus]`).
@immutable
class CoinPack {
  const CoinPack(this.name, this.price, this.coins, this.bonus);

  final String name;
  final int price;
  final int coins;
  final int bonus;

  int get total => coins + bonus;
}
