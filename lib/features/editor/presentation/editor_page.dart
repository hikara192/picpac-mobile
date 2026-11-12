import 'package:design_core/design_core.dart' hide TextAlign;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/motion.dart';
import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../render/sheet_layout.dart';
import '../../_shared/application/async_retry.dart';
import '../../_shared/application/design_session.dart';
import '../../_shared/application/document_capabilities.dart';
import '../../_shared/application/import_controller.dart';
import '../../../core/presentation/a11y.dart';
import '../../_shared/presentation/media_messages.dart';
import '../../_shared/presentation/sheet_scene.dart';
import '../../../core/presentation/state_views.dart';
import '../../_shared/presentation/sync_status_line.dart';
import '../application/editor_tools.dart';
import '../application/frame_gesture.dart';
import 'assistant_sheet.dart';
import 'widgets/crop_handles.dart';
import 'widgets/editor_tool_bar.dart';
import 'widgets/editor_tool_panels.dart';

export '../../../app/routes.dart' show EditorFocus;

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({required this.designId, this.focus, super.key});

  final String designId;

  final EditorFocus? focus;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  PageController? _pager;
  int _sheetIndex = 0;
  EditorTool? _tool;
  bool _appliedInitialFocus = false;

  ({String spreadId, String slotId})? _swapFrom;

  Slot? _gestureBase;
  Offset _pan = Offset.zero;
  SheetLayout? _layout;

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  DesignSessionController get _controller =>
      ref.read(designSessionProvider(widget.designId).notifier);

  int _sceneToken = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = designSessionProvider(widget.designId);
    final session = ref.watch(provider);
    final state = session.value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.actionBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: _close,
        ),
        title: Text(
          state == null || state.spreads.isEmpty
              ? l10n.editorTitle
              : l10n.editorSheetOf(
                  _visibleIndex(state) + 1,
                  state.spreads.length,
                ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            onPressed: state?.canUndo ?? false ? _controller.undo : null,
            tooltip: l10n.createUndo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: state?.canRedo ?? false ? _controller.redo : null,
            tooltip: l10n.createRedo,
            icon: const Icon(Icons.redo),
          ),
          TextButton(onPressed: _done, child: Text(l10n.editorDone)),
          const SizedBox(width: PicPacSpacing.xxs),
        ],
      ),
      body: switch (session) {
        AsyncData<DesignSessionState>(:final value) => _buildEditor(value),
        AsyncError<DesignSessionState>(:final error) => FailureView(
          failure: failureOr(error),
          onRetry: () => ref.invalidate(provider),
          onLogin: () => context.push(
            AppRoutes.loginFor(AppRoutes.editorFor(widget.designId)),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  int _visibleIndex(DesignSessionState state) =>
      _sheetIndex.clamp(0, state.spreads.length - 1);

  Widget _buildEditor(DesignSessionState state) {
    final l10n = AppLocalizations.of(context);
    if (state.spreads.isEmpty) {
      return EmptyView(
        title: l10n.createEmptyTitle,
        body: l10n.createEmptyBody,
        icon: Icons.photo_library_outlined,
        hero: true,
        action: MinTapTarget(
          child: FilledButton.icon(
            onPressed: _addPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: Text(l10n.createAddPhotos),
          ),
        ),
      );
    }
    _applyInitialFocus(state);
    final index = _visibleIndex(state);
    final spread = state.spreads[index];
    final slot = _activeSlot(state, spread);
    final pager = _pagerFor(state);
    final capabilities = ref.watch(documentCapabilitiesProvider);
    _clampPagerAfterRemoval(pager, state.spreads.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            controller: pager,
            physics: _tool == EditorTool.frame
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: state.spreads.length,
            onPageChanged: (page) => _onPageChanged(state, page),
            itemBuilder: (context, page) =>
                _sheetPage(state, state.spreads[page]),
          ),
        ),
        SyncStatusLine(state: state),
        if (_tool == null)
          const SizedBox.shrink()
        else
          AnimatedSwitcher(
            duration: motionDuration(context, Motion.panel),
            switchInCurve: Motion.easeOutCubic,
            switchOutCurve: Motion.easeOutCubic,
            child: EditorToolPanel(
              key: ValueKey<EditorTool>(_tool!),
              designId: widget.designId,
              tool: _tool!,
              state: state,
              spread: spread,
              slot: slot,
              onAddPhotos: _addPhotos,
              swapFromIndex: _swapSourceIndex(state),
              onCancelSwap: () => setState(() => _swapFrom = null),
            ),
          ),
        EditorToolBar(
          selected: _tool,
          isEnabled: (tool) => _toolEnabled(tool, capabilities),
          onSelect: _selectTool,
          onAssistant: _openAssistant,
          canAssist: state.spreads.isNotEmpty,
        ),
      ],
    );
  }

  Widget _sheetPage(DesignSessionState state, Spread spread) {
    final l10n = AppLocalizations.of(context);
    final template = state.templateOf(spread);
    final selectedSlotId = state.selectedSpreadId == spread.id
        ? state.selectedSlotId
        : null;
    final scene = Padding(
      padding: const EdgeInsets.all(PicPacSpacing.md),
      child: Center(
        child: SheetScene(
          designId: widget.designId,
          document: state.document,
          spread: spread,
          template: template,
          spec: state.spec,
          selectedSlotId: selectedSlotId,
          showGuides: true,
          maxSide: 2048,
          slotDecodeTargets: true,
          semanticLabel: l10n.a11ySheetPreview(
            _visibleIndex(state) + 1,
            state.spreads.length,
          ),
          builder: (context, layout, _) {
            _layout = layout;
            return _InteractionLayer(
              layout: layout,
              spread: spread,
              selectedSlotId: selectedSlotId,
              framed: _tool == EditorTool.frame,
              onTapSlot: (slotId) => _onTapSlot(spread, slotId),
              onAddPhoto: _addPhotos,
              onGestureStart: () => _startGesture(state, spread),
              onGestureUpdate: (pan, scale) =>
                  _updateGesture(state, spread, pan, scale),
              onGestureEnd: _endGesture,
              onHandleStart: () => _startGesture(state, spread),
              onHandleUpdate: (corner, delta) =>
                  _resizeGesture(state, spread, corner, delta),
              onHandleEnd: _endGesture,
            );
          },
        ),
      ),
    );
    return AnimatedSwitcher(
      duration: motionDuration(context, Motion.slow),
      switchInCurve: Motion.easeOutCubic,
      switchOutCurve: Motion.easeOutCubic,
      child: KeyedSubtree(
        key: ValueKey<String>('sheet-${spread.id}-$_sceneToken'),
        child: scene,
      ),
    );
  }

  Slot? _activeSlot(DesignSessionState state, Spread spread) {
    if (state.selectedSpreadId != spread.id) return null;
    final slotId = state.selectedSlotId;
    if (slotId == null) return null;
    return spread.slotById(slotId);
  }

  void _applyInitialFocus(DesignSessionState state) {
    final focus = widget.focus;
    if (_appliedInitialFocus || focus == null) {
      _appliedInitialFocus = true;
      return;
    }
    _appliedInitialFocus = true;
    final index = state.spreads.indexWhere(
      (spread) => spread.id == focus.spreadId,
    );
    if (index >= 0) _sheetIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selectSlot(focus.spreadId, focus.slotId);
    });
  }

  PageController _pagerFor(DesignSessionState state) {
    final existing = _pager;
    if (existing != null) return existing;
    final focus = widget.focus;
    var index = 0;
    if (focus != null) {
      final found = state.spreads.indexWhere(
        (spread) => spread.id == focus.spreadId,
      );
      if (found > 0) index = found;
    }
    _sheetIndex = index;
    return _pager = PageController(initialPage: index);
  }

  void _clampPagerAfterRemoval(PageController pager, int sheetCount) {
    if (sheetCount <= 0) return;
    if (_sheetIndex > sheetCount - 1) _sheetIndex = sheetCount - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !pager.hasClients) return;
      final page = pager.page?.round() ?? 0;
      if (page <= sheetCount - 1) return;
      pager.jumpToPage(sheetCount - 1);
    });
  }

  void _onPageChanged(DesignSessionState state, int page) {
    if (page < 0 || page >= state.spreads.length) return;
    final spread = state.spreads[page];
    setState(() {
      _sheetIndex = page;
      _swapFrom = null;
    });
    _controller.selectSpread(spread.id);
    if (_tool != null && _tool!.needsPhoto) {
      _selectFirstPhoto(state, spread);
    } else {
      _controller.selectSlot(spread.id, null);
    }
  }

  void _onTapSlot(Spread spread, String slotId) {
    if (_tool == EditorTool.swap) {
      _handleSwapTap(spread, slotId);
      return;
    }
    _controller.selectSlot(spread.id, slotId);
  }

  void _handleSwapTap(Spread spread, String slotId) {
    final target = spread.slotById(slotId);
    if (target == null || target.photoId == null) return;
    final from = _swapFrom;
    if (from == null || from.spreadId != spread.id) {
      setState(() => _swapFrom = (spreadId: spread.id, slotId: slotId));
      _controller.selectSlot(spread.id, slotId);
      return;
    }
    if (from.slotId == slotId) return;
    _controller.execute(
      SwapSlots(
        spreadA: from.spreadId,
        slotA: from.slotId,
        spreadB: spread.id,
        slotB: slotId,
      ),
    );
    setState(() => _swapFrom = null);
    _controller.selectSlot(spread.id, slotId);
  }

  int? _swapSourceIndex(DesignSessionState state) {
    final from = _swapFrom;
    if (from == null) return null;
    final photoId = state.document
        .slotById(from.spreadId, from.slotId)
        ?.photoId;
    if (photoId == null) return null;
    final index = state.document.assets.indexWhere(
      (asset) => asset.id == photoId,
    );
    return index < 0 ? null : index + 1;
  }

  bool _toolEnabled(EditorTool tool, DocumentCapabilities capabilities) =>
      switch (tool) {
        EditorTool.rotate => capabilities.rotate,
        EditorTool.swap => capabilities.swap,
        _ => true,
      };

  void _selectTool(EditorTool tool) {
    final capabilities = ref.read(documentCapabilitiesProvider);
    if (!_toolEnabled(tool, capabilities)) return;
    final next = _tool == tool ? null : tool;
    setState(() {
      _tool = next;
      _swapFrom = null;
    });
    if (next == null || !next.needsPhoto) return;
    final state = ref.read(designSessionProvider(widget.designId)).value;
    if (state == null || state.spreads.isEmpty) return;
    final spread = state.spreads[_visibleIndex(state)];
    _selectFirstPhoto(state, spread);
    if (next == EditorTool.swap) {
      final fresh = ref.read(designSessionProvider(widget.designId)).value;
      final selected = fresh == null ? null : _activeSlot(fresh, spread);
      if (selected?.photoId != null) {
        setState(() => _swapFrom = (spreadId: spread.id, slotId: selected!.id));
      }
    }
  }

  void _selectFirstPhoto(DesignSessionState state, Spread spread) {
    final current = _activeSlot(state, spread);
    if (current?.photoId != null) return;
    for (final slot in spread.slots) {
      if (slot.photoId != null) {
        _controller.selectSlot(spread.id, slot.id);
        return;
      }
    }
    _controller.selectSlot(spread.id, null);
  }

  Future<void> _openAssistant() async {
    final state = ref.read(designSessionProvider(widget.designId)).value;
    if (state == null || state.spreads.isEmpty) return;
    final spread = state.spreads[_visibleIndex(state)];
    final applied = await showAssistantSheet(
      context,
      designId: widget.designId,
      spreadId: spread.id,
    );
    if (!applied || !mounted) return;
    setState(() => _sceneToken++);
  }

  Future<void> _addPhotos() async {
    final state = ref.read(designSessionProvider(widget.designId)).value;
    if (state == null) return;
    await ref
        .read(importControllerProvider(widget.designId).notifier)
        .pickAndImport();
    if (!mounted) return;
    final failure = ref
        .read(importControllerProvider(widget.designId))
        .pickerFailure;
    if (failure == null) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pickerFailureText(l10n, failure))));
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.createFor(widget.designId));
    }
  }

  void _done() {
    _controller.flush();
    _close();
  }

  void _startGesture(DesignSessionState state, Spread spread) {
    final slot = _activeSlot(state, spread);
    if (slot == null || slot.photoId == null) return;
    _gestureBase = slot;
    _pan = Offset.zero;
    _controller.beginGesture('gesture.frame');
  }

  Size _photoExtent(Slot slot, Size slotSize) => slot.rotation.swapsAxes
      ? Size(slotSize.height, slotSize.width)
      : slotSize;

  void _updateGesture(
    DesignSessionState state,
    Spread spread,
    Offset pan,
    double scale,
  ) {
    final base = _gestureBase;
    if (base == null) return;
    _pan += pan;
    final layout = _layout;
    if (layout == null) return;
    final transform = FrameGesture.panAndZoom(
      base: base,
      panPixels: photoDeltaOf(_pan, rotation: base.rotation, flipH: base.flipH),
      scale: scale,
      slotSize: _photoExtent(base, layout.rectOf(base.id).size),
    );
    _controller.execute(
      SetCrop(
        spreadId: spread.id,
        slotId: base.id,
        crop: base.crop,
        zoom: transform.zoom,
        anchor: transform.anchor,
      ),
    );
  }

  void _resizeGesture(
    DesignSessionState state,
    Spread spread,
    CropCorner corner,
    Offset delta,
  ) {
    final base = _gestureBase;
    final layout = _layout;
    if (base == null || layout == null) return;
    final crop = FrameGesture.resize(
      base: base.crop,
      corner: layout.photoCornerFor(base.id, corner),
      deltaPixels: photoDeltaOf(
        delta,
        rotation: base.rotation,
        flipH: base.flipH,
      ),
      slotSize: _photoExtent(base, layout.rectOf(base.id).size),
    );
    _controller.execute(
      SetCrop(
        spreadId: spread.id,
        slotId: base.id,
        crop: crop,
        zoom: base.zoom,
        anchor: base.anchor,
      ),
    );
  }

  void _endGesture() {
    _gestureBase = null;
    _pan = Offset.zero;
    _controller.endGesture();
  }
}

class _InteractionLayer extends StatelessWidget {
  const _InteractionLayer({
    required this.layout,
    required this.spread,
    required this.selectedSlotId,
    required this.framed,
    required this.onTapSlot,
    required this.onAddPhoto,
    required this.onGestureStart,
    required this.onGestureUpdate,
    required this.onGestureEnd,
    required this.onHandleStart,
    required this.onHandleUpdate,
    required this.onHandleEnd,
  });

  final SheetLayout layout;
  final Spread spread;
  final String? selectedSlotId;
  final bool framed;
  final void Function(String slotId) onTapSlot;
  final VoidCallback onAddPhoto;
  final VoidCallback onGestureStart;
  final void Function(Offset pan, double scale) onGestureUpdate;
  final VoidCallback onGestureEnd;
  final VoidCallback onHandleStart;
  final void Function(CropCorner corner, Offset delta) onHandleUpdate;
  final VoidCallback onHandleEnd;

  @override
  Widget build(BuildContext context) {
    final selected = selectedSlotId == null
        ? null
        : spread.slotById(selectedSlotId!);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final slotId = layout.slotAt(details.localPosition);
        if (slotId != null) onTapSlot(slotId);
      },
      onScaleStart: framed ? (details) => onGestureStart() : null,
      onScaleUpdate: framed
          ? (details) => onGestureUpdate(details.focalPointDelta, details.scale)
          : null,
      onScaleEnd: framed ? (details) => onGestureEnd() : null,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          for (final slot in spread.slots)
            if (slot.photoId == null)
              Positioned.fromRect(
                rect: layout.rectOf(slot.id),
                child: _EmptySlotButton(
                  compact: layout.rectOf(slot.id).width < 150,
                  onTap: onAddPhoto,
                ),
              ),
          if (framed && selected?.photoId != null)
            CropHandles(
              layout: layout,
              slotId: selected!.id,
              visible: true,
              onStart: onHandleStart,
              onUpdate: onHandleUpdate,
              onEnd: onHandleEnd,
            ),
        ],
      ),
    );
  }
}

class _EmptySlotButton extends StatelessWidget {
  const _EmptySlotButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Tooltip(
        message: l10n.createAddPhotos,
        child: compact
            ? SizedBox(
                width: kMinTouchTarget,
                height: kMinTouchTarget,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(kMinTouchTarget),
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.add, size: 24),
                ),
              )
            : FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  l10n.createAddPhotos,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
      ),
    );
  }
}
