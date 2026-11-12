import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../core/media/asset_cache.dart';
import '../../../core/media/image_probe.dart';
import '../../../core/media/photo_importer.dart';
import '../../../core/media/photo_normalizer.dart';
import '../../../core/media/photo_picker.dart';
import '../../../core/media/photo_storage.dart';
import '../../../core/media/photo_uploader.dart';
import '../../../render/asset_image_store.dart';
import 'design_format.dart';

final Provider<DesignAssetCache> designAssetCacheProvider =
    Provider<DesignAssetCache>(
      (ref) => DesignAssetCache(rootDirectory: ref.watch(draftRootProvider)),
    );

final Provider<ImageProbePort> imageProbeProvider = Provider<ImageProbePort>(
  (ref) => const UiImageProbe(),
);

final Provider<PhotoPickerPort> photoPickerProvider = Provider<PhotoPickerPort>(
  (ref) => ImagePickerPhotoPicker(),
);

final Provider<PhotoStoragePort> photoStorageProvider =
    Provider<PhotoStoragePort>(
      (ref) => DioPhotoStorage(logger: ref.watch(loggerProvider)),
    );

final Provider<PhotoNormalizerPort> photoNormalizerProvider =
    Provider<PhotoNormalizerPort>((ref) => const PlatformPhotoNormalizer());

final Provider<PhotoImporter> photoImporterProvider = Provider<PhotoImporter>(
  (ref) => PhotoImporter(
    picker: ref.watch(photoPickerProvider),
    cache: ref.watch(designAssetCacheProvider),
    probe: ref.watch(imageProbeProvider),
    normalizer: ref.watch(photoNormalizerProvider),
    logger: ref.watch(loggerProvider),
  ),
);

final Provider<PhotoUploader> photoUploaderProvider = Provider<PhotoUploader>(
  (ref) => PhotoUploader(
    api: ref.watch(apiPortProvider),
    storage: ref.watch(photoStorageProvider),
    logger: ref.watch(loggerProvider),
  ),
);

typedef AssetStoreKey = ({String designId, int maxSide});

final assetImageStoreProvider = Provider.family<AssetImageStore, AssetStoreKey>(
  (ref, key) {
    final store = AssetImageStore(
      cache: ref.watch(designAssetCacheProvider),
      designId: key.designId,
      maxSide: key.maxSide,
    );
    ref.onDispose(store.dispose);
    return store;
  },
  isAutoDispose: true,
);
