import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../models/catalog_models.dart';
import '../../models/design_model.dart';
import '../mappers.dart';
import '../repositories.dart';
import 'supabase_errors.dart';

/// Profile, wallet and saved designs of the signed-in user. All writes that
/// touch coins go through SQL functions; the tables are read-only for clients.
class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppException('Sign in required');
    return id;
  }

  Future<T> _guard<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      logBackendError(action, e);
      throw friendlyError(e);
    }
  }

  @override
  Future<UserSnapshot> load() => _guard('load user data', () async {
        final uid = _uid;
        final results = await Future.wait<Object?>([
          _client
              .from('profiles')
              .select('full_name,email,role,coins,is_premium')
              .eq('id', uid)
              .single(),
          _client.from('unlocked_templates').select('template_id'),
          _client
              .from('coin_transactions')
              .select('label,amount')
              .order('created_at', ascending: false),
          _client.from('user_tasks').select('task_key'),
          _client
              .from('user_designs')
              .select()
              .order('updated_at', ascending: false),
        ]);
        final profile = Map<String, dynamic>.from(results[0] as Map);
        List<Map<String, dynamic>> rows(Object? v) =>
            List<Map<String, dynamic>>.from(v as List);
        return UserSnapshot(
          name: profile['full_name'] as String,
          email: profile['email'] as String,
          role: profile['role'] == 'creator'
              ? AccountRole.creator
              : AccountRole.customer,
          coins: (profile['coins'] as num).toInt(),
          premium: profile['is_premium'] == true,
          unlocked: [
            for (final r in rows(results[1])) (r['template_id'] as num).toInt()
          ],
          history: [
            for (final r in rows(results[2]))
              CoinTx(r['label'] as String, (r['amount'] as num).toInt())
          ],
          doneTasks: {for (final r in rows(results[3])) r['task_key'] as String},
          designs: [for (final r in rows(results[4])) userDesignFromRow(r)],
        );
      });

  @override
  Future<bool> unlockTemplate(int templateId) => _guard(
      'unlock template $templateId',
      () async => (await _client
          .rpc('unlock_template', params: {'p_template_id': templateId})) == true);

  @override
  Future<bool> claimTask(String key) => _guard(
      'claim task $key',
      () async =>
          (await _client.rpc('claim_task', params: {'p_key': key})) == true);

  @override
  Future<void> sendCoins(String recipientEmail, int amount) =>
      _guard('send coins', () async {
        await _client.rpc('send_coins',
            params: {'p_recipient': recipientEmail, 'p_amount': amount});
      });

  @override
  Future<void> buyPack(int packId) => _guard('buy pack $packId', () async {
        await _client.rpc('buy_coin_pack', params: {'p_pack_id': packId});
      });

  @override
  Future<void> saveDesign(DesignModel design) =>
      _guard('save design ${design.id}', () async {
        await _client
            .from('user_designs')
            .upsert(userDesignToRow(design, _uid), onConflict: 'user_id,id');
      });

  @override
  Future<void> deleteDesign(int id) => _guard('delete design $id', () async {
        await _client
            .from('user_designs')
            .delete()
            .eq('user_id', _uid)
            .eq('id', id);
      });
}
