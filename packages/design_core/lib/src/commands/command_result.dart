import 'package:meta/meta.dart';

enum CommandErrorCode {
  spreadNotFound('spread_not_found'),

  slotNotFound('slot_not_found'),

  photoNotFound('photo_not_found'),

  photoNotInDocument('photo_not_in_document'),

  duplicateId('duplicate_id'),

  invalidIndex('invalid_index'),

  invalidValue('invalid_value'),

  invalidTarget('invalid_target'),

  slotOccupied('slot_occupied'),

  invalidState('invalid_state'),

  unknown('unknown');

  const CommandErrorCode(this.wire);

  final String wire;
}

@immutable
final class CommandError {
  const CommandError({
    required this.code,
    required this.message,
    this.targetId,
    this.args = const <String, Object?>{},
  });

  final CommandErrorCode code;

  final String message;

  final String? targetId;

  final Map<String, Object?> args;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code.wire,
    'message': message,
    if (targetId != null) 'targetId': targetId,
    if (args.isNotEmpty) 'args': args,
  };

  @override
  String toString() {
    final target = targetId == null ? '' : ' ($targetId)';
    return 'CommandError(${code.wire})$target: $message';
  }
}

sealed class CommandResult {
  const CommandResult();

  bool get isOk;

  bool get isFailed => !isOk;

  CommandError? get error;
}

final class CommandOk extends CommandResult {
  const CommandOk();

  @override
  bool get isOk => true;

  @override
  CommandError? get error => null;

  @override
  String toString() => 'CommandOk()';
}

final class CommandFailed extends CommandResult {
  const CommandFailed(this.error);

  @override
  final CommandError error;

  @override
  bool get isOk => false;

  @override
  String toString() => 'CommandFailed($error)';
}

final class DesignCommandException implements Exception {
  const DesignCommandException(this.error);

  final CommandError error;

  @override
  String toString() => 'DesignCommandException($error)';
}
