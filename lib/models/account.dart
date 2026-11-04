import 'package:flutter/foundation.dart';

enum AccountRole { customer, creator }

/// The signed-in user (`profiles` row of the Supabase backend).
@immutable
class Account {
  const Account(
      {required this.name, this.role = AccountRole.customer, this.email = ''});

  final String name;
  final String email;
  final AccountRole role;

  bool get isCreator => role == AccountRole.creator;

  Account copyWith({String? name, AccountRole? role, String? email}) => Account(
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email);
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
  const CoinPack(this.name, this.price, this.coins, this.bonus,
      {this.id = 0, this.popular = false});

  /// `coin_packs.id` (what the server needs to credit the purchase).
  final int id;
  final bool popular;
  final String name;
  final int price;
  final int coins;
  final int bonus;

  int get total => coins + bonus;
}
