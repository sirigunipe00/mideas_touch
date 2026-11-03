import 'package:flutter/painting.dart';
import '../models/account.dart';
import '../models/design_element.dart';
import '../models/design_model.dart';

/// Parses `#rrggbb` into a [Color].
Color hex(String value) {
  var v = value.replaceAll('#', '');
  if (v.length == 3) v = v.split('').map((c) => '$c$c').join();
  return Color(int.parse('FF$v', radix: 16));
}

class StockAsset {
  const StockAsset(this.emoji, this.keywords);
  final String emoji;
  final String keywords;
}

/// Local dummy data. Everything below is copied from the declarative
/// constants of the original HTML artifact (`CATS`, `FONTS`, `AS`, `BG`, `T`,
/// the three seed designs and the coin packs).
class Catalog {
  Catalog._();

  static const categories = <String>[
    'Festivals',
    'Offers',
    'Promotions',
    'Business',
    'Events',
    'Food',
    'Retail',
    'Announcements',
    'Greetings',
    'Social Media',
    'Seasonal',
    'Other',
  ];

  static const fonts = <String>[
    'Poppins',
    'Playfair Display',
    'Pacifico',
    'Bebas Neue',
    'Noto Sans Devanagari',
    'Hind',
    'Baloo 2',
  ];

  static const assets = <StockAsset>[
    StockAsset('🪔', 'diya diwali lamp'),
    StockAsset('🍔', 'burger food'),
    StockAsset('🎂', 'cake birthday'),
    StockAsset('🛍️', 'shopping sale offer'),
    StockAsset('🎉', 'party event'),
    StockAsset('☀️', 'summer sun'),
    StockAsset('👟', 'shoes retail'),
    StockAsset('🍕', 'pizza restaurant food'),
    StockAsset('🎁', 'gift offer'),
    StockAsset('🌸', 'flower spring'),
    StockAsset('☕', 'coffee cafe'),
    StockAsset('🚀', 'launch new'),
  ];

  static final backgrounds = <List<Color>>[
    [hex('#8a6a00'), hex('#efbf05')],
    [hex('#7c2d12'), hex('#f59e0b')],
    [hex('#0e7490'), hex('#a78bfa')],
    [hex('#111827'), hex('#6d28d9')],
    [hex('#15803d'), hex('#facc15')],
    [hex('#be185d'), hex('#fb923c')],
  ];

  static const coinPacks = <CoinPack>[
    CoinPack('Basic', 10, 1, 0),
    CoinPack('Advance', 50, 5, 2),
    CoinPack('Pro', 100, 10, 5),
  ];

  static const _shade = Color.fromRGBO(0, 0, 0, .28);

  static DesignModel _mk(
    int id,
    String name,
    String cat,
    String desc,
    String c1,
    String c2,
    String emoji,
    String title,
    String sub,
    String textColor,
    String font,
  ) {
    final tc = hex(textColor);
    return DesignModel(
      id: id,
      name: name,
      cat: cat,
      desc: desc,
      bg: [hex(c1), hex(c2)],
      by: (id == 3 || id == 6) ? 'You' : 'Studio Team',
      pm: const [2, 4, 6, 8].contains(id),
      cost: const {2: 149, 4: 129, 6: 199, 8: 119}[id] ?? 0,
      els: [
        DesignElement.text(
            x: 8,
            y: 9,
            w: 84,
            text: title,
            font: font,
            size: 44,
            color: tc,
            bold: true),
        DesignElement.image(x: 29, y: 37, w: 42, emoji: emoji, photo: true),
        const DesignElement.shape(
            x: 12,
            y: 77,
            w: 76,
            h: 12,
            fill: _shade,
            shape: ShapeStyle.pill),
        DesignElement.text(
            x: 12, y: 79.6, w: 76, text: sub, size: 18, color: tc),
      ],
    );
  }

  /// The eight starter templates.
  static List<DesignModel> templates() => [
        _mk(1, 'Diwali Sale', 'Festivals',
            'Festive offer poster with a glowing diya.', '#7c2d12', '#f59e0b',
            '🪔', 'Diwali\nSale', 'Up to 50% OFF', '#ffffff', 'Playfair Display'),
        _mk(2, 'Weekend Offer', 'Offers',
            'Bold weekend discount creative for shops.', '#4c1d95', '#ec4899',
            '🛍️', 'Weekend\nOffer', 'Flat 30% on everything', '#ffffff',
            'Bebas Neue'),
        _mk(3, 'Birthday Bash', 'Greetings', 'A cheerful birthday invitation.',
            '#0e7490', '#a78bfa', '🎂', 'Happy\nBirthday',
            'Join the party at 7 PM', '#ffffff', 'Pacifico'),
        _mk(4, 'Restaurant Special', 'Food',
            'Daily special card for cafes and restaurants.', '#991b1b',
            '#f97316', '🍔', 'Chef’s\nSpecial', 'Fresh and hot, every day',
            '#fff7ed', 'Playfair Display'),
        _mk(5, 'Independence Day', 'Festivals', 'Patriotic greeting in Hindi.',
            '#ea580c', '#15803d', '🇮🇳', 'स्वतंत्रता\nदिवस', 'शुभकामनाएं',
            '#ffffff', 'Noto Sans Devanagari'),
        _mk(6, 'Grand Opening', 'Events', 'Announce your new store opening.',
            '#1e3a8a', '#06b6d4', '🎉', 'Grand\nOpening',
            'This Saturday, 10 AM', '#ffffff', 'Bebas Neue'),
        _mk(7, 'New Arrival', 'Retail', 'Launch card for new products.',
            '#111827', '#6d28d9', '👟', 'New\nArrival', 'Now in stores',
            '#ffffff', 'Poppins'),
        _mk(8, 'Summer Sale', 'Seasonal', 'Bright seasonal sale creative.',
            '#f59e0b', '#ef4444', '☀️', 'Summer\nSale',
            'Cool deals, hot prices', '#ffffff', 'Pacifico'),
      ];

  /// The three saved designs that appear in "My Designs" after registering.
  static List<DesignModel> savedDesigns(List<DesignModel> templates) {
    DesignModel from(int index, int id, String name, String status,
            String mod) =>
        templates[index].copyWith(id: id, name: name, status: status, mod: mod);
    return [
      from(0, 101, 'Diwali Promotion', 'Completed', 'Today, 10:42 AM'),
      from(2, 102, 'Birthday Invite', 'Draft', 'Yesterday, 6:15 PM'),
      from(4, 103, 'Independence Day Wishes', 'Draft', 'Oct 28, 4:05 PM'),
    ];
  }
}
