import 'package:meta/meta.dart';

import '../document/design_document.dart';
import 'command_result.dart';

abstract class DesignCommand {
  const DesignCommand();

  String get kind;

  int get revisionDelta => 1;

  CommandResult validate(DesignDocument document);

  DesignDocument apply(DesignDocument document) {
    final result = validate(document);
    if (result case CommandFailed(:final error)) {
      throw DesignCommandException(error);
    }
    return applyValidated(document);
  }

  @internal
  DesignDocument applyValidated(DesignDocument document) =>
      applyCore(document).copyWith(revision: document.revision + revisionDelta);

  DesignDocument applyCore(DesignDocument document);

  DesignCommand invert(DesignDocument preState) =>
      InvertedCommand(invertCore(preState));

  @internal
  DesignCommand invertCore(DesignDocument preState);

  bool coalesce(DesignCommand next) => false;

  Map<String, Object?> describe();
}

class CompositeCommand extends DesignCommand {
  CompositeCommand(
    Iterable<DesignCommand> commands, {
    this.revisionDelta = 1,
    this.label = 'composite',
  }) : commands = List<DesignCommand>.unmodifiable(commands);

  final List<DesignCommand> commands;

  @override
  final int revisionDelta;

  final String label;

  bool get isEmpty => commands.isEmpty;

  @override
  String get kind => label;

  @override
  CommandResult validate(DesignDocument document) {
    if (commands.isEmpty) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidState,
          message: 'a composite command requires at least one child',
        ),
      );
    }
    var current = document;
    for (final command in commands) {
      final result = command.validate(current);
      if (result is CommandFailed) return result;
      current = command.applyCore(current);
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    var current = document;
    for (final command in commands) {
      current = command.applyCore(current);
    }
    return current;
  }

  @override
  DesignCommand invertCore(DesignDocument preState) {
    var current = preState;
    final inverses = <DesignCommand>[];
    for (final command in commands) {
      inverses.add(command.invert(current));
      current = command.applyCore(current);
    }
    return CompositeCommand(inverses.reversed, label: 'undo:$label');
  }

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'revisionDelta': revisionDelta,
    'ops': <Object?>[for (final command in commands) command.describe()],
  };

  @override
  String toString() => 'CompositeCommand($kind, ${commands.length} ops)';
}

final class InvertedCommand extends DesignCommand {
  InvertedCommand(this.inner);

  final DesignCommand inner;

  @override
  String get kind => 'undo:${inner.kind}';

  @override
  int get revisionDelta => -inner.revisionDelta;

  @override
  CommandResult validate(DesignDocument document) => inner.validate(document);

  @override
  DesignDocument applyCore(DesignDocument document) =>
      inner.applyCore(document);

  @override
  DesignCommand invert(DesignDocument preState) => inner;

  @override
  DesignCommand invertCore(DesignDocument preState) =>
      inner.invertCore(preState);

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'op': inner.describe(),
  };

  @override
  String toString() => 'InvertedCommand(${inner.kind})';
}
