import 'dart:io';

import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/media/asset_cache.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/presentation/a11y.dart';
import '../../../_shared/presentation/photo_reveal.dart';
import '../../application/import_controller.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    required this.designId,
    required this.assets,
    required this.cache,
    required this.onReorder,
    required this.onRemove,
    required this.onAdd,
    this.uploads = const <ImportTask>[],
    this.onCancelUpload,
    this.onRetryUpload,
    this.onSelect,
    this.selectedAssetId,
    this.enabled = true,
    this.canAdd = true,
    super.key,
  });

  final String designId;

  final List<PhotoAsset> assets;

  final DesignAssetCache cache;

  final List<ImportTask> uploads;

  final void Function(int from, int to) onReorder;

  final void Function(PhotoAsset asset) onRemove;

  final VoidCallback onAdd;

  final void Function(ImportTask task)? onCancelUpload;

  final void Function(ImportTask task)? onRetryUpload;

  final void Function(PhotoAsset asset)? onSelect;

  final String? selectedAssetId;

  final bool enabled;

  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final count = assets.length + uploads.length + (canAdd ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: PicPacSpacing.sm,
        crossAxisSpacing: PicPacSpacing.sm,
      ),
      itemBuilder: (context, index) {
        if (index < assets.length) {
          return _assetTile(assets[index], index);
        }
        final uploadIndex = index - assets.length;
        if (uploadIndex < uploads.length) {
          return _UploadTile(
            task: uploads[uploadIndex],
            index: assets.length + uploadIndex,
            onCancel: onCancelUpload,
            onRetry: onRetryUpload,
          );
        }
        return _AddTile(onTap: canAdd ? onAdd : null);
      },
    );
  }

  Widget _assetTile(PhotoAsset asset, int index) {
    final tile = _PhotoTile(
      designId: designId,
      asset: asset,
      index: index,
      cache: cache,
      selected: asset.id == selectedAssetId,
      onRemove: () => onRemove(asset),
      onSelect: onSelect == null ? null : () => onSelect!(asset),
    );
    if (!enabled) return tile;
    return DragTarget<int>(
      key: ValueKey<String>('photo_tile_$index'),
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onReorder(details.data, index),
      builder: (context, candidate, rejected) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PicPacRadii.photo),
          border: Border.all(
            color: candidate.isEmpty ? Colors.transparent : PicPacColors.accent,
            width: 2,
          ),
        ),
        child: LongPressDraggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 96,
              height: 96,
              child: Opacity(opacity: 0.9, child: tile),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: tile),
          hapticFeedbackOnStart: true,
          child: tile,
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.createAddPhotos,
      child: Tooltip(
        message: l10n.createAddPhotos,
        child: Material(
          key: const Key('photo-add-tile'),
          color: PicPacColors.accent,
          borderRadius: BorderRadius.circular(PicPacRadii.photo),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(PicPacRadii.photo),
            child: const Center(
              child: Icon(Icons.add, size: 32, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.task,
    required this.index,
    this.onCancel,
    this.onRetry,
  });

  final ImportTask task;

  final int index;

  final void Function(ImportTask task)? onCancel;
  final void Function(ImportTask task)? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failed = task.hasFailed;
    return Semantics(
      label: failed
          ? l10n.createUploadFailed
          : l10n.createPhotoUploading(index + 1),
      image: !failed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PicPacRadii.photo),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(
              task.prepared.cachedFile,
              fit: BoxFit.cover,
              cacheWidth: 360,
              filterQuality: FilterQuality.low,
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: PicPacColors.fillStone),
            ),
            ColoredBox(color: PicPacColors.inkStrong.withValues(alpha: 0.18)),
            Positioned(
              left: PicPacSpacing.xxs,
              top: PicPacSpacing.xxs,
              child: _NumberBadge(label: '${index + 1}'),
            ),
            if (failed)
              Positioned.fill(
                child: MinTapTarget(
                  child: InkWell(
                    key: Key('photo-upload-retry-${task.localId}'),
                    onTap: onRetry == null ? null : () => onRetry!(task),
                    child: Semantics(
                      button: true,
                      label: l10n.createUploadRetry(index + 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(height: PicPacSpacing.xxs),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: PicPacSpacing.xs,
                            ),
                            child: Text(
                              l10n.createUploadFailed,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                right: 0,
                top: 0,
                child: _CancelUploadKnob(
                  task: task,
                  index: index,
                  onCancel: onCancel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CancelUploadKnob extends StatelessWidget {
  const _CancelUploadKnob({
    required this.task,
    required this.index,
    this.onCancel,
  });

  final ImportTask task;
  final int index;
  final void Function(ImportTask task)? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.createCancelUpload(index + 1);
    return SizedBox(
      width: kMinTouchTarget,
      height: kMinTouchTarget,
      child: Center(
        child: Tooltip(
          message: label,
          child: Material(
            color: PicPacColors.inkStrong.withValues(alpha: 0.66),
            shape: const CircleBorder(),
            child: InkWell(
              key: Key('photo-upload-cancel-${task.localId}'),
              customBorder: const CircleBorder(),
              onTap: onCancel == null ? null : () => onCancel!(task),
              child: Semantics(
                button: true,
                label: label,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      value: task.progress <= 0 ? null : task.progress,
                      strokeWidth: 2,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({
    required this.designId,
    required this.asset,
    required this.index,
    required this.cache,
    required this.onRemove,
    this.selected = false,
    this.onSelect,
  });

  final String designId;
  final PhotoAsset asset;
  final int index;
  final DesignAssetCache cache;
  final VoidCallback onRemove;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late Future<File?> _file = widget.cache.fileFor(
    widget.designId,
    widget.asset.sha256,
  );

  @override
  void didUpdateWidget(_PhotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.sha256 != widget.asset.sha256 ||
        oldWidget.designId != widget.designId) {
      _file = widget.cache.fileFor(widget.designId, widget.asset.sha256);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = widget.selected;
    return Semantics(
      label: l10n.createPhotoNumber(widget.index + 1),
      image: true,
      selected: selected,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PicPacRadii.photo),
          border: selected
              ? Border.all(color: PicPacColors.accent, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PicPacRadii.photo),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                onTap: widget.onSelect,
                child: FutureBuilder<File?>(
                  future: _file,
                  builder: (context, snapshot) {
                    final file = snapshot.data;
                    if (file == null) {
                      return const ColoredBox(color: PicPacColors.fillStone);
                    }
                    return PhotoReveal(
                      key: ValueKey<String>(
                        'photo-reveal-${widget.asset.sha256}',
                      ),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        cacheWidth: 360,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (context, error, stack) =>
                            const ColoredBox(
                              color: PicPacColors.fillStone,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: PicPacColors.muted,
                              ),
                            ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: PicPacSpacing.xxs,
                top: PicPacSpacing.xxs,
                child: _NumberBadge(label: '${widget.index + 1}'),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: SizedBox(
                  width: kMinTouchTarget,
                  height: kMinTouchTarget,
                  child: Center(
                    child: Tooltip(
                      message: l10n.createRemovePhoto(widget.index + 1),
                      child: Material(
                        color: PicPacColors.inkStrong.withValues(alpha: 0.66),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: widget.onRemove,
                          child: Semantics(
                            button: true,
                            label: l10n.createRemovePhoto(widget.index + 1),
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PicPacSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: PicPacColors.inkStrong.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(PicPacRadii.xs),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}
