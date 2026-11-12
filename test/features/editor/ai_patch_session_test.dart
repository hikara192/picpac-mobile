import 'package:design_core/design_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/design_session.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(registerDesignFallbacks);

  DesignPatch patch(List<Map<String, Object?>> ops, {int baseRevision = 1}) =>
      DesignPatch.fromJsonOrThrow(<String, Object?>{
        'schema': 1,
        'baseRevision': baseRevision,
        'ops': ops,
      });

  Future<({DesignHarness harness, ProviderContainer container})> open() async {
    final harness = await DesignHarness.create();
    addTearDown(harness.dispose);
    final document = await harness.seedPhotos(count: 2);
    harness.stubBasics(design: designDto(document: document));
    final container = harness.mount();
    addTearDown(container.dispose);
    await container.read(designSessionProvider('dsg_1').future);
    return (harness: harness, container: container);
  }

  test('невалидный патч отклоняется целиком и не трогает документ', () async {
    final setup = await open();
    final session = setup.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    final before = setup.container
        .read(designSessionProvider('dsg_1'))
        .value!
        .document;

    final result = session.applyAiPatch(
      patch(<Map<String, Object?>>[
        <String, Object?>{'op': 'applyLook', 'lookId': 'mono', 'strength': 1},
        <String, Object?>{
          'op': 'assignPhoto',
          'spreadId': 'sheet_1',
          'slotId': 'main',
          'photoId': 'ghost',
        },
      ], baseRevision: before.revision),
    );

    expect(result.isErr, isTrue);
    expect(
      (result.failureOrNull! as PatchRejected).reason,
      PatchErrorCode.photoNotFound,
    );
    expect(
      setup.container.read(designSessionProvider('dsg_1')).value!.document,
      before,
    );
    expect(
      setup.container.read(designSessionProvider('dsg_1')).value!.canUndo,
      isFalse,
    );
  });

  test('валидный патч — один шаг отмены', () async {
    final setup = await open();
    final session = setup.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    final before = setup.container
        .read(designSessionProvider('dsg_1'))
        .value!
        .document;

    final result = session.applyAiPatch(
      patch(<Map<String, Object?>>[
        <String, Object?>{'op': 'applyLook', 'lookId': 'mono', 'strength': 1},
        <String, Object?>{
          'op': 'setAdjustment',
          'field': 'exposure',
          'value': 0.15,
        },
        <String, Object?>{
          'op': 'setBackground',
          'type': 'color',
          'value': '#FFF8F0',
        },
      ], baseRevision: before.revision),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');

    final applied = setup.container.read(designSessionProvider('dsg_1')).value!;
    expect(applied.canUndo, isTrue);
    expect(applied.document, isNot(before));
    expect(applied.document.spreadById('sheet_1')!.background.value, '#FFF8F0');

    session.undo();
    final undone = setup.container.read(designSessionProvider('dsg_1')).value!;
    expect(undone.document, before);
    expect(undone.canUndo, isFalse);
  });

  test('патч на чужую ревизию отклоняется без изменений', () async {
    final setup = await open();
    final session = setup.container.read(
      designSessionProvider('dsg_1').notifier,
    );
    final before = setup.container
        .read(designSessionProvider('dsg_1'))
        .value!
        .document;

    final result = session.applyAiPatch(
      patch(<Map<String, Object?>>[
        <String, Object?>{'op': 'applyLook', 'lookId': 'warm', 'strength': 1},
      ], baseRevision: before.revision + 5),
    );

    expect(result.isErr, isTrue);
    expect(
      (result.failureOrNull! as PatchRejected).reason,
      PatchErrorCode.revisionMismatch,
    );
    expect(
      setup.container.read(designSessionProvider('dsg_1')).value!.document,
      before,
    );
  });
}
