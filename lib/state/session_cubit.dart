import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/account.dart';
import '../models/design_model.dart';

class SessionState {
  const SessionState({
    this.user,
    this.fullName = '',
    this.registering = true,
    this.coins = 0,
    this.unlocked = const [],
    this.done = const {},
    this.history = const [],
    this.inviteSent = false,
    this.designs = const [],
    this.premium = false,
    this.myDesignsFilter = 'Recent',
  });

  /// `null` while browsing as a guest.
  final Account? user;

  /// The "Full name" field of the register form (`S.nm`).
  final String fullName;

  /// Register (true) or Login (false) tab of the auth sheet.
  final bool registering;
  final int coins;
  final List<int> unlocked;

  /// Completed "earn coins" tasks: `f`ollow, `r`efer, `t`ag.
  final Map<String, bool> done;
  final List<CoinTx> history;
  final bool inviteSent;

  /// The user's saved designs ("My Designs").
  final List<DesignModel> designs;
  final bool premium;
  final String myDesignsFilter;

  bool get signedIn => user != null;
  bool get isCreator => user?.isCreator ?? false;

  /// The artifact's `lk(d)`: a design is locked until it has been unlocked
  /// with a coin (creators never lock their own designs).
  bool isLocked(DesignModel d) =>
      !((isCreator && d.by == 'You') || unlocked.contains(d.id));

  SessionState copyWith({
    Object? user = _keep,
    String? fullName,
    bool? registering,
    int? coins,
    List<int>? unlocked,
    Map<String, bool>? done,
    List<CoinTx>? history,
    bool? inviteSent,
    List<DesignModel>? designs,
    bool? premium,
    String? myDesignsFilter,
  }) {
    return SessionState(
      user: identical(user, _keep) ? this.user : user as Account?,
      fullName: fullName ?? this.fullName,
      registering: registering ?? this.registering,
      coins: coins ?? this.coins,
      unlocked: unlocked ?? this.unlocked,
      done: done ?? this.done,
      history: history ?? this.history,
      inviteSent: inviteSent ?? this.inviteSent,
      designs: designs ?? this.designs,
      premium: premium ?? this.premium,
      myDesignsFilter: myDesignsFilter ?? this.myDesignsFilter,
    );
  }
}

const Object _keep = Object();

/// The local account: sign-in state, coins, unlocked designs and saved
/// designs. Everything lives in memory (dummy data, no backend).
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({required List<DesignModel> seedDesigns})
      : _seed = seedDesigns,
        super(const SessionState());

  final List<DesignModel> _seed;
  bool _seeded = false;

  void setRegistering(bool value) => emit(state.copyWith(registering: value));

  void setFullName(String value) => emit(state.copyWith(fullName: value));

  void setFilter(String value) => emit(state.copyWith(myDesignsFilter: value));

  /// Create the account / log in. Matches `signIn()` of the artifact: the
  /// credentials are not validated, the name defaults to "Aarav".
  void signIn({AccountRole role = AccountRole.customer}) {
    final name = state.fullName.isEmpty ? 'Aarav' : state.fullName;
    var designs = state.designs;
    if (!_seeded) {
      designs = _seed;
      _seeded = true;
    }
    emit(state.copyWith(
        user: Account(name: name, role: role), designs: designs));
  }

  /// Developer affordance: switch between customer and creator accounts.
  void toggleCreator() {
    final u = state.user;
    if (u == null) return;
    emit(state.copyWith(
        user: u.copyWith(
            role: u.isCreator ? AccountRole.customer : AccountRole.creator)));
  }

  void logout() {
    _seeded = false;
    emit(SessionState(
      registering: state.registering,
      fullName: state.fullName,
      premium: state.premium,
    ));
  }

  void addCoins(int n, String label) {
    emit(state.copyWith(
        coins: state.coins + n, history: [CoinTx(label, n), ...state.history]));
  }

  /// Returns false when the task was already completed.
  bool earn(String key, String label) {
    if (state.done[key] == true) return false;
    emit(state.copyWith(done: {...state.done, key: true}));
    addCoins(1, label);
    return true;
  }

  void markInviteSent() => emit(state.copyWith(inviteSent: true));

  void unlock(DesignModel d) {
    emit(state.copyWith(
      coins: state.coins - 1,
      unlocked: [...state.unlocked, d.id],
      history: [CoinTx('Unlocked ${d.name}', -1), ...state.history],
    ));
  }

  /// Returns an error message, or `null` when the coins were sent.
  String? sendCoins(String recipient, String amount) {
    final r = recipient.trim();
    final n = (double.tryParse(amount.trim()) ?? 0).floor();
    if (r.isEmpty) return 'Enter who to send to';
    if (!(n >= 1)) return 'Enter number of coins';
    if (n > state.coins) return 'Not enough coins';
    emit(state.copyWith(
      coins: state.coins - n,
      history: [CoinTx('Sent to $r', -n), ...state.history],
    ));
    return null;
  }

  void saveDesign(DesignModel d) {
    final list = [...state.designs];
    final i = list.indexWhere((x) => x.id == d.id);
    if (i < 0) {
      list.insert(0, d);
    } else {
      list[i] = d;
    }
    emit(state.copyWith(designs: list));
  }

  void deleteDesign(int id) => emit(
      state.copyWith(designs: state.designs.where((d) => d.id != id).toList()));
}
