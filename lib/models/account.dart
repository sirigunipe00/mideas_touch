import 'package:flutter/foundation.dart';

enum AccountRole { customer, creator }

/// The signed-in user (`profiles` row of the Supabase backend).
@immutable
class Account {
  const Account({
    required this.name,
    this.id = '',
    this.role = AccountRole.customer,
    this.email = '',
  });

  /// Supabase `profiles.id` / auth user id (used in invite links).
  final String id;
  final String name;
  final String email;
  final AccountRole role;

  bool get isCreator => role == AccountRole.creator;

  Account copyWith({
    String? id,
    String? name,
    AccountRole? role,
    String? email,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        email: email ?? this.email,
      );
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
