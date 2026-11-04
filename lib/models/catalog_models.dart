import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'account.dart';
import 'design_model.dart';

/// Parses `#rrggbb` (or `#rgb`) into a [Color].
Color hex(String value) {
  var v = value.replaceAll('#', '');
  if (v.length == 3) v = v.split('').map((c) => '$c$c').join();
  return Color(int.parse('FF$v', radix: 16));
}

/// One stock picture of the editor "Images" tab (an emoji today).
@immutable
class StockAsset {
  const StockAsset(this.emoji, this.keywords);
  final String emoji;
  final String keywords;
}

/// A row of "Earn coins" on the wallet screen (`earn_tasks`).
@immutable
class EarnTask {
  const EarnTask({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.historyLabel,
    this.reward = 1,
  });

  final String key;
  final String icon;
  final String title;
  final String description;
  final String buttonLabel;
  final String historyLabel;
  final int reward;
}

/// A hero slide of the home screen (`banners`). Hindi texts are optional.
@immutable
class HomeBanner {
  const HomeBanner({
    required this.tag,
    required this.title,
    required this.body,
    required this.button,
    this.tagHi,
    this.titleHi,
    this.bodyHi,
    this.buttonHi,
    required this.action,
    required this.colors,
    this.dark = false,
  });

  final String tag;
  final String title;
  final String body;
  final String button;
  final String? tagHi;
  final String? titleHi;
  final String? bodyHi;
  final String? buttonHi;

  /// `startCreating`, `earnCoins`, `seePacks` or `explore`.
  final String action;
  final List<Color> colors;
  final bool dark;
}

/// Everything the app shows that is not specific to the signed-in user.
@immutable
class CatalogData {
  const CatalogData({
    this.categories = const [],
    this.fonts = const [],
    this.assets = const [],
    this.backgrounds = const [],
    this.coinPacks = const [],
    this.earnTasks = const [],
    this.banners = const [],
    this.templates = const [],
  });

  final List<String> categories;
  final List<String> fonts;
  final List<StockAsset> assets;
  final List<List<Color>> backgrounds;
  final List<CoinPack> coinPacks;
  final List<EarnTask> earnTasks;
  final List<HomeBanner> banners;
  final List<DesignModel> templates;

  CatalogData copyWith({List<DesignModel>? templates}) => CatalogData(
        categories: categories,
        fonts: fonts,
        assets: assets,
        backgrounds: backgrounds,
        coinPacks: coinPacks,
        earnTasks: earnTasks,
        banners: banners,
        templates: templates ?? this.templates,
      );
}

/// A signed-in user's server data (`profiles`, wallet tables, `user_designs`).
@immutable
class UserSnapshot {
  const UserSnapshot({
    required this.name,
    required this.email,
    this.role = AccountRole.customer,
    this.coins = 0,
    this.premium = false,
    this.unlocked = const [],
    this.history = const [],
    this.doneTasks = const {},
    this.designs = const [],
  });

  final String name;
  final String email;
  final AccountRole role;
  final int coins;
  final bool premium;
  final List<int> unlocked;
  final List<CoinTx> history;
  final Set<String> doneTasks;
  final List<DesignModel> designs;
}
