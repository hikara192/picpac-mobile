import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class GuestWorkState {
  const GuestWorkState({
    this.designId,
    this.cartId,
    this.signedInSince = false,
  });

  final String? designId;

  final String? cartId;

  final bool signedInSince;

  bool get hasDesign => designId != null;

  bool get hasWork => designId != null || cartId != null;

  GuestWorkState copyWith({
    String? designId,
    String? cartId,
    bool? signedInSince,
  }) => GuestWorkState(
    designId: designId ?? this.designId,
    cartId: cartId ?? this.cartId,
    signedInSince: signedInSince ?? this.signedInSince,
  );
}

final class GuestWorkStore extends Notifier<GuestWorkState> {
  @override
  GuestWorkState build() => const GuestWorkState();

  void rememberDesign(String designId, {required UserRole role}) {
    if (role != UserRole.guest) return;
    if (state.designId == designId) return;
    state = state.copyWith(designId: designId);
  }

  void rememberCart(String cartId, {required UserRole role}) {
    if (role != UserRole.guest) return;
    if (state.cartId == cartId) return;
    state = state.copyWith(cartId: cartId);
  }

  void signedIn() {
    if (!state.hasWork || state.signedInSince) return;
    state = state.copyWith(signedInSince: true);
  }

  void clear() => state = const GuestWorkState();

  void forgetDesign(String designId) {
    if (state.designId != designId) return;
    state = GuestWorkState(
      cartId: state.cartId,
      signedInSince: state.signedInSince,
    );
  }
}

final guestWorkProvider = NotifierProvider<GuestWorkStore, GuestWorkState>(
  GuestWorkStore.new,
);
