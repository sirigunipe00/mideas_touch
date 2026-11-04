import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../models/catalog_models.dart';
import '../mappers.dart';
import '../repositories.dart';
import 'supabase_config.dart';
import 'supabase_errors.dart';

typedef Rows = List<Map<String, dynamic>>;

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  /// Pictures already requested in this session (in memory only).
  final Map<String, Future<Uint8List?>> _images = {};

  Future<Rows> _table(String name, String columns,
      {String order = 'sort_order'}) async {
    final rows = await _client.from(name).select(columns).order(order);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<CatalogData> load() async {
    try {
      final results = await Future.wait([
        _table('categories', 'name'),
        _table('fonts', 'family'),
        _table('backgrounds', 'color_from,color_to'),
        _table('stock_assets', 'emoji,keywords'),
        _table('coin_packs', 'id,name,price_inr,coins,bonus_coins,is_popular'),
        _table('earn_tasks',
            'key,icon,title,description,button_label,history_label,reward_coins'),
        _table('banners',
            'tag,title,body,button_label,tag_hi,title_hi,body_hi,button_label_hi,action,color_from,color_to,is_dark'),
        _table(
            'templates',
            'id,name,description,bg_from,bg_to,background_image_path,author_name,'
                'is_premium,price_inr,categories(name),template_elements(*)'),
      ]);
      return CatalogData(
        categories: [for (final r in results[0]) r['name'] as String],
        fonts: [for (final r in results[1]) r['family'] as String],
        backgrounds: [
          for (final r in results[2])
            [hex(r['color_from'] as String), hex(r['color_to'] as String)]
        ],
        assets: [
          for (final r in results[3])
            StockAsset(r['emoji'] as String, (r['keywords'] as String?) ?? '')
        ],
        coinPacks: [
          for (final r in results[4])
            CoinPack(
              r['name'] as String,
              (r['price_inr'] as num).toInt(),
              (r['coins'] as num).toInt(),
              (r['bonus_coins'] as num).toInt(),
              id: (r['id'] as num).toInt(),
              popular: r['is_popular'] == true,
            )
        ],
        earnTasks: [
          for (final r in results[5])
            EarnTask(
              key: r['key'] as String,
              icon: r['icon'] as String,
              title: r['title'] as String,
              description: r['description'] as String,
              buttonLabel: r['button_label'] as String,
              historyLabel: r['history_label'] as String,
              reward: (r['reward_coins'] as num).toInt(),
            )
        ],
        banners: [
          for (final r in results[6])
            HomeBanner(
              tag: r['tag'] as String,
              title: r['title'] as String,
              body: r['body'] as String,
              button: r['button_label'] as String,
              tagHi: r['tag_hi'] as String?,
              titleHi: r['title_hi'] as String?,
              bodyHi: r['body_hi'] as String?,
              buttonHi: r['button_label_hi'] as String?,
              action: r['action'] as String,
              colors: [hex(r['color_from'] as String), hex(r['color_to'] as String)],
              dark: r['is_dark'] == true,
            )
        ],
        templates: [for (final r in results[7]) templateFromRow(r)],
      );
    } catch (e) {
      logBackendError('load catalogue', e);
      throw friendlyError(e);
    }
  }

  @override
  Future<Uint8List?> image(String path) =>
      _images.putIfAbsent(path, () => _download(path)).then((bytes) {
        // A failed download must not be remembered, so it can be retried.
        if (bytes == null) _images.remove(path);
        return bytes;
      });

  Future<Uint8List?> _download(String path) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _client.storage
            .from(SupabaseConfig.assetsBucket)
            .download(path);
      } catch (e) {
        logBackendError('download $path', e);
        if (attempt == 2) return null;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    return null;
  }
}
