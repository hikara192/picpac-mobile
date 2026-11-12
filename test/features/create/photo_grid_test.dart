import 'dart:io';

import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/core/media/asset_cache.dart';
import 'package:picpac_mobile/core/media/photo_importer.dart';
import 'package:picpac_mobile/core/media/photo_uploader.dart';
import 'package:picpac_mobile/features/_shared/application/import_controller.dart';
import 'package:picpac_mobile/features/create/presentation/widgets/photo_grid.dart';
import 'package:picpac_mobile/l10n/app_localizations.dart';

import '../support/design_fixtures.dart';
import '../support/design_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late DesignAssetCache cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('picpac_gallery_');
    cache = DesignAssetCache(rootDirectory: () async => root);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Widget app({
    required List<PhotoAsset> assets,
    List<ImportTask> uploads = const <ImportTask>[],
    void Function(String localId)? onCancel,
    void Function(PhotoAsset asset)? onRemove,
    VoidCallback? onAdd,
  }) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          child: PhotoGrid(
            designId: 'dsg_gallery',
            assets: assets,
            uploads: uploads,
            cache: cache,
            onReorder: (from, to) {},
            onRemove: onRemove ?? (asset) {},
            onAdd: onAdd ?? () {},
            onCancelUpload: onCancel == null
                ? null
                : (task) => onCancel(task.localId),
          ),
        ),
      ),
    ),
  );

  testWidgets('3 фото + загрузка: прогресс в кружке, «+» последняя', (
    tester,
  ) async {
    final file = await tester.runAsync(
      () => writePng(root, 'uploading.png', width: 60),
    );
    final photo = PreparedPhoto(
      cachedFile: file!,
      sha256: 'upload_hash',
      fileName: 'uploading.png',
      mimeType: 'image/png',
      bytes: 1,
      widthPx: 60,
      heightPx: 60,
    );
    final cancelled = <String>[];
    await tester.pumpWidget(
      app(
        assets: <PhotoAsset>[
          photoAsset(id: 'p1', widthPx: 700, heightPx: 900),
          photoAsset(id: 'p2', widthPx: 700, heightPx: 900),
          photoAsset(id: 'p3', widthPx: 700, heightPx: 900),
        ],
        uploads: <ImportTask>[
          ImportTask(
            localId: 'upload_hash',
            fileName: 'uploading.png',
            bytes: 1,
            prepared: photo,
            stage: PhotoUploadStage.transferring,
            progress: 0.4,
          ),
        ],
        onCancel: cancelled.add,
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Добавить фото'), findsWidgets);
    expect(find.byKey(const Key('photo-add-tile')), findsOneWidget);

    final addRect = tester.getRect(find.byKey(const Key('photo-add-tile')));
    final uploadRect = tester.getRect(
      find.byKey(const Key('photo-upload-cancel-upload_hash')),
    );
    expect(
      addRect.left > uploadRect.left || addRect.top > uploadRect.top,
      isTrue,
      reason: 'плитка «+» должна идти после загружаемого фото',
    );

    await tester.tap(find.byKey(const Key('photo-upload-cancel-upload_hash')));
    expect(cancelled, <String>['upload_hash']);
  });

  testWidgets('после загрузки крестик удаляет фото', (tester) async {
    final removed = <String>[];
    await tester.pumpWidget(
      app(
        assets: <PhotoAsset>[
          photoAsset(id: 'p1', widthPx: 700, heightPx: 900),
          photoAsset(id: 'p2', widthPx: 700, heightPx: 900),
          photoAsset(id: 'p3', widthPx: 700, heightPx: 900),
        ],
        onRemove: (asset) => removed.add(asset.id),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip('Удалить фото 2'));
    expect(removed, <String>['p2']);
  });

  testWidgets('на лимите плитка «+» исчезает', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PhotoGrid(
            designId: 'dsg_gallery',
            assets: <PhotoAsset>[
              photoAsset(id: 'p1', widthPx: 700, heightPx: 900),
            ],
            cache: cache,
            canAdd: false,
            onReorder: (from, to) {},
            onRemove: (asset) {},
            onAdd: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('photo-add-tile')), findsNothing);
  });
}
