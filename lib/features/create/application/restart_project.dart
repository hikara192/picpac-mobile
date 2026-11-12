import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/orders/preflight_ack.dart';
import '../../../core/session/guest_work.dart';
import '../../../core/session/session_service.dart';
import '../../../core/storage/draft_store.dart';

final class ProjectRestarter {
  ProjectRestarter({
    required this._api,
    required this._session,
    required this._drafts,
    this._onRestarted,
  });

  final ApiPort _api;
  final SessionService _session;
  final DraftStore _drafts;
  final void Function(String oldDesignId)? _onRestarted;

  Future<bool> canRestart(String designId) async =>
      await _drafts.load(designId) != null;

  Future<Result<DesignDto>> restart(String designId) async {
    final snapshot = await _drafts.load(designId);
    if (snapshot == null) {
      return Err<DesignDto>(
        ApiFailure(
          code: ApiErrorCode.notFound,
          message: 'no local snapshot to rebuild design $designId',
        ),
      );
    }
    final document = snapshot.copyWith(revision: 0);
    final result = await _session.ensureSession(
      () => _api.createDesign(document),
    );
    if (result case Ok<DesignDto>(:final value)) {
      try {
        await _drafts.saveNow(
          value.document,
          designId: value.id,
          productId: value.document.product.id,
        );
      } on Object {
      }
      _onRestarted?.call(designId);
    }
    return result;
  }
}

final Provider<ProjectRestarter> projectRestarterProvider =
    Provider<ProjectRestarter>(
      (ref) => ProjectRestarter(
        api: ref.watch(apiPortProvider),
        session: ref.watch(sessionServiceProvider),
        drafts: ref.watch(draftStoreProvider),
        onRestarted: (oldDesignId) {
          ref.read(preflightAckProvider.notifier).forget(oldDesignId);
          ref.read(guestWorkProvider.notifier).forgetDesign(oldDesignId);
        },
      ),
    );
