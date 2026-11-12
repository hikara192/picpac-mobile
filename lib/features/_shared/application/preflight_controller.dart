import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/analytics.dart';
import '../../../core/orders/cart_pricing.dart';
import '../../../core/orders/preflight_ack.dart';
import '../../../core/session/session_service.dart';
import 'async_retry.dart';
import 'design_session.dart';

final class PreflightView {
  const PreflightView({
    required this.local,
    this.server,
    this.serverFailure,
    this.acknowledged = false,
  });

  final PreflightReport local;

  final PreflightReport? server;

  final Failure? serverFailure;

  final bool acknowledged;

  PreflightReport get report => PreflightReport(
    server?.issues ?? local.issues,
    acknowledged: acknowledged,
  );

  bool get usesServer => server != null;

  List<PreflightIssue> get serverDifferences {
    final remote = server;
    if (remote == null) return const <PreflightIssue>[];
    final localKeys = <String>{
      for (final issue in local.issues) '${issue.code.wire}/${issue.targetId}',
    };
    return <PreflightIssue>[
      for (final issue in remote.issues)
        if (!localKeys.contains('${issue.code.wire}/${issue.targetId}')) issue,
    ];
  }

  PreflightView acknowledge() => acknowledged
      ? this
      : PreflightView(
          local: local,
          server: server,
          serverFailure: serverFailure,
          acknowledged: true,
        );
}

final class PreflightController extends AsyncNotifier<PreflightView> {
  PreflightController(this.designId);

  final String designId;

  @override
  Future<PreflightView> build() async {
    final api = ref.watch(apiPortProvider);
    final session = ref.watch(sessionServiceProvider);
    final analytics = ref.watch(analyticsProvider);
    final design = await ref.watch(designSessionProvider(designId).future);

    final local = PreflightProjection.run(
      document: design.document,
      spec: design.spec,
      templates: design.templates,
    );

    final apiId = design.serverId;
    final remote = apiId == null
        ? const Err<PreflightDto>(
            ApiFailure(
              code: ApiErrorCode.notFound,
              message: 'the project has no server copy yet',
            ),
          )
        : await session.ensureSession(() => api.preflight(apiId));
    final acknowledged = ref
        .read(preflightAckProvider.notifier)
        .covers(designId, design.serverRevision);
    final view = switch (remote) {
      Ok<PreflightDto>(:final value) => PreflightView(
        local: local,
        server: PreflightReport(
          value.issues,
          acknowledged: value.acknowledged || acknowledged,
        ),
        acknowledged: acknowledged,
      ),
      Err<PreflightDto>(:final error) => PreflightView(
        local: local,
        serverFailure: error,
        acknowledged: acknowledged,
      ),
    };

    analytics.track(AnalyticsEvent.preflightShown, <String, Object?>{
      'blocking': view.report.blockingCount,
      'warnings': view.report.warningCount,
      'source': view.usesServer ? 'server' : 'local',
      'photos': design.document.photoCount,
    });
    return view;
  }

  void acknowledge() {
    final view = state.value;
    if (view == null || view.acknowledged) return;
    final issues = view.report.blocking;
    final revision = ref
        .read(designSessionProvider(designId))
        .value
        ?.serverRevision;
    if (revision != null) {
      ref.read(preflightAckProvider.notifier).acknowledge(designId, revision);
    }
    ref.read(analyticsProvider).track(
      AnalyticsEvent.preflightOverridden,
      <String, Object?>{
        'blocking': issues.length,
        'codes': <String>[for (final issue in issues) issue.code.wire],
        'revision': view.report.issues.length,
        'source': view.usesServer ? 'server' : 'local',
      },
    );
    ref.read(loggerProvider).warning('preflight.override', <String, Object?>{
      'designId': designId,
      'codes': <String>[for (final issue in issues) issue.code.wire],
      'targets': <String>[for (final issue in issues) issue.targetId],
    });
    state = AsyncData<PreflightView>(view.acknowledge());
  }

  Future<Failure?> addToCart() async {
    final api = ref.read(apiPortProvider);
    final session = ref.read(sessionServiceProvider);
    final design = ref.read(designSessionProvider(designId)).value;
    if (design == null) {
      return const ApiFailure(
        code: ApiErrorCode.networkUnavailable,
        message: 'the project is not loaded yet',
      );
    }
    final quantity = cartQuantityFor(
      format: design.format,
      document: design.document,
    );
    final apiId = design.serverId;
    if (apiId == null) {
      return const ApiFailure(
        code: 'local_project',
        message: 'the project has no server copy yet',
      );
    }
    final result = await session.ensureSession(
      () => api.addCartItem(
        AddCartItemRequest(designId: apiId, quantity: quantity),
      ),
    );
    return result.failureOrNull;
  }
}

final preflightProvider =
    AsyncNotifierProvider.family<PreflightController, PreflightView, String>(
      PreflightController.new,
      retry: noProviderRetry,
    );
