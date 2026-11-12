import '../document/design_document.dart';
import '../document/geometry.dart';
import 'command_result.dart';
import 'command_utils.dart';
import 'design_command.dart';

final class SetSlotOrientation extends DesignCommand {
  const SetSlotOrientation({
    required this.spreadId,
    required this.slotId,
    required this.rotation,
    required this.flipH,
  });

  final String spreadId;

  final String slotId;

  final int rotation;

  final bool flipH;

  factory SetSlotOrientation.turn({
    required String spreadId,
    required String slotId,
    required QuarterTurn rotation,
    bool flipH = false,
  }) => SetSlotOrientation(
    spreadId: spreadId,
    slotId: slotId,
    rotation: rotation.degrees,
    flipH: flipH,
  );

  QuarterTurn? get turn => QuarterTurn.tryParse(rotation);

  @override
  String get kind => 'setSlotOrientation';

  @override
  CommandResult validate(DesignDocument document) {
    final spread = document.spreadById(spreadId);
    if (spread == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadId" not found',
          targetId: spreadId,
        ),
      );
    }
    if (spread.slotById(slotId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.slotNotFound,
          message: 'slot "$slotId" not found in "$spreadId"',
          targetId: slotId,
        ),
      );
    }
    if (turn == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'rotation must be a multiple of 90 within 0..270 degrees',
          targetId: slotId,
          args: <String, Object?>{'rotation': rotation},
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final spread = document.spreadById(spreadId)!;
    final slot = spread
        .slotById(slotId)!
        .copyWith(rotation: turn, flipH: flipH);
    return replaceSpread(document, spreadId, (spread) => spread.withSlot(slot));
  }

  @override
  DesignCommand invertCore(DesignDocument preState) {
    final slot = preState.slotById(spreadId, slotId)!;
    return SetSlotOrientation(
      spreadId: spreadId,
      slotId: slotId,
      rotation: slot.rotation.degrees,
      flipH: slot.flipH,
    );
  }

  @override
  bool coalesce(DesignCommand next) =>
      next is SetSlotOrientation &&
      next.spreadId == spreadId &&
      next.slotId == slotId;

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'spreadId': spreadId,
    'slotId': slotId,
    'rotation': rotation,
    'flipH': flipH,
  };

  @override
  String toString() =>
      'SetSlotOrientation($spreadId/$slotId → $rotation°${flipH ? ', flip' : ''})';
}

final class SwapSlots extends DesignCommand {
  const SwapSlots({
    required this.spreadA,
    required this.slotA,
    required this.spreadB,
    required this.slotB,
  });

  final String spreadA;

  final String slotA;

  final String spreadB;

  final String slotB;

  @override
  String get kind => 'swapSlots';

  @override
  CommandResult validate(DesignDocument document) {
    final first = document.slotById(spreadA, slotA);
    if (document.spreadById(spreadA) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadA" not found',
          targetId: spreadA,
        ),
      );
    }
    if (first == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.slotNotFound,
          message: 'slot "$slotA" not found in "$spreadA"',
          targetId: slotA,
        ),
      );
    }
    if (document.spreadById(spreadB) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "$spreadB" not found',
          targetId: spreadB,
        ),
      );
    }
    final second = document.slotById(spreadB, slotB);
    if (second == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.slotNotFound,
          message: 'slot "$slotB" not found in "$spreadB"',
          targetId: slotB,
        ),
      );
    }
    if (spreadA == spreadB && slotA == slotB) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'cannot swap a slot with itself',
          targetId: slotA,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final a = document.slotById(spreadA, slotA)!;
    final b = document.slotById(spreadB, slotB)!;
    var next = replaceSpread(
      document,
      spreadA,
      (spread) => spread.withSlot(a.withFramingOf(b)),
    );
    next = replaceSpread(
      next,
      spreadB,
      (spread) => spread.withSlot(b.withFramingOf(a)),
    );
    return next;
  }

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      SwapSlots(spreadA: spreadB, slotA: slotB, spreadB: spreadA, slotB: slotA);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'fromSpread': spreadA,
    'fromSlot': slotA,
    'toSpread': spreadB,
    'toSlot': slotB,
  };

  @override
  String toString() => 'SwapSlots($spreadA/$slotA ↔ $spreadB/$slotB)';
}
