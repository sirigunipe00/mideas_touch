import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/account.dart';
import '../models/catalog_models.dart';
import '../models/design_model.dart';

class SessionState {
  const SessionState({
    this.user,
    this.fullName = '',
    this.registering = true,
    this.busy = false,
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

  /// A register / login request is in flight.
  final bool busy;
  final int coins;
  final List<int> unlocked;

  /// Completed "earn coins" tasks, by `earn_tasks.key`.
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
    bool? busy,
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
      busy: busy ?? this.busy,
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

/// The signed-in account as the app shows it. The truth lives in Supabase
/// (see `UserRepository`); this cubit only mirrors what the server returned.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(const SessionState());

  void setRegistering(bool value) => emit(state.copyWith(registering: value));

  void setFullName(String value) => emit(state.copyWith(fullName: value));

  void setFilter(String value) => emit(state.copyWith(myDesignsFilter: value));

  void setBusy(bool value) => emit(state.copyWith(busy: value));

  /// Mirrors the server data after sign-in or after any wallet change.
  void applySnapshot(UserSnapshot s) {
    final current = state.user;
    emit(state.copyWith(
      // A creator-mode override (hidden developer toggle) survives refreshes.
      user: Account(
          name: s.name, email: s.email, role: current?.role ?? s.role),
      coins: s.coins,
      premium: s.premium,
      unlocked: s.unlocked,
      history: s.history,
      done: {for (final k in s.doneTasks) k: true},
      designs: s.designs,
    ));
  }

  /// Hands a downloaded Storage picture to every saved design that uses it.
  void attachDesignImage(String path, Uint8List bytes) {
    if (!state.designs.any((d) => d.biPath == path && d.bi == null)) return;
    emit(state.copyWith(designs: [
      for (final d in state.designs)
        d.biPath == path && d.bi == null ? d.copyWith(bi: bytes) : d
    ]));
  }

  /// Developer affordance: switch between customer and creator accounts.
  /// (Creator features are on hold; this only changes what the UI shows.)
  void toggleCreator() {
    final u = state.user;
    if (u == null) return;
    emit(state.copyWith(
        user: u.copyWith(
            role: u.isCreator ? AccountRole.customer : AccountRole.creator)));
  }

  void logout() {
    emit(SessionState(
      registering: state.registering,
      fullName: state.fullName,
    ));
  }

  void markInviteSent() => emit(state.copyWith(inviteSent: true));

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
