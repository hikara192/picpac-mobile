import '../commands/command_result.dart';
import '../commands/design_command.dart';
import '../document/design_document.dart';

class UndoStack {
  UndoStack({required DesignDocument document, int limit = defaultLimit})
    : this._(document, limit);

  UndoStack._(this._document, this._limit)
    : assert(_limit > 0, 'limit must be positive');

  static const int defaultLimit = 100;

  final int _limit;
  DesignDocument _document;
  final List<_HistoryEntry> _undo = <_HistoryEntry>[];
  final List<_HistoryEntry> _redo = <_HistoryEntry>[];
  final List<void Function()> _listeners = <void Function()>[];
  _Group? _group;
  bool _coalesceAllowed = false;

  DesignDocument get document => _document;

  int get limit => _limit;

  bool get canUndo => _group == null && _undo.isNotEmpty;

  bool get canRedo => _group == null && _redo.isNotEmpty;

  int get undoDepth => _undo.length;

  int get redoDepth => _redo.length;

  bool get isGrouping => _group != null;

  bool get canCoalesce =>
      _coalesceAllowed && _group == null && _undo.isNotEmpty;

  String? get nextUndoLabel => _undo.isEmpty ? null : _undo.last.label;

  String? get nextRedoLabel => _redo.isEmpty ? null : _redo.last.label;

  CommandResult execute(DesignCommand command) {
    final validation = command.validate(_document);
    if (validation is CommandFailed) return validation;

    final pre = _document;
    final inverse = command.invert(pre);

    final group = _group;
    if (group != null) {
      _document = command.applyCore(pre);
      group.commands.add(command);
      group.inverses.add(inverse);
      _notify();
      return const CommandOk();
    }

    _document = command.applyValidated(pre);
    _redo.clear();

    if (_coalesceAllowed && _undo.isNotEmpty) {
      final last = _undo.last;
      if (last.forward.coalesce(command)) {
        _undo[_undo.length - 1] = _HistoryEntry(
          forward: command,
          inverse: last.inverse,
          label: last.label,
        );
        _coalesceAllowed = true;
        _notify();
        return const CommandOk();
      }
    }

    _undo.add(
      _HistoryEntry(forward: command, inverse: inverse, label: command.kind),
    );
    _trim();
    _coalesceAllowed = true;
    _notify();
    return const CommandOk();
  }

  void beginGroup([String label = 'group']) {
    assert(_group == null, 'a group is already open');
    if (_group != null) return;
    _group = _Group(label: label, startRevision: _document.revision);
    _coalesceAllowed = false;
    _notify();
  }

  CommandResult endGroup() {
    final group = _group;
    if (group == null) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidState,
          message: 'endGroup called without beginGroup',
        ),
      );
    }
    _group = null;
    if (group.commands.isEmpty) {
      _coalesceAllowed = false;
      _notify();
      return const CommandOk();
    }
    final forward = group.commands.length == 1
        ? group.commands.single
        : CompositeCommand(
            group.commands,
            revisionDelta: 1,
            label: group.label,
          );
    final inverse = CompositeCommand(
      group.inverses.reversed,
      revisionDelta: -1,
      label: 'undo:${group.label}',
    );
    _document = _document.copyWith(revision: group.startRevision + 1);
    _undo.add(
      _HistoryEntry(forward: forward, inverse: inverse, label: group.label),
    );
    _redo.clear();
    _trim();
    _coalesceAllowed = false;
    _notify();
    return const CommandOk();
  }

  bool undo() {
    if (!canUndo) return false;
    final entry = _undo.last;
    final validation = entry.inverse.validate(_document);
    if (validation is CommandFailed) return false;
    _document = entry.inverse.applyValidated(_document);
    _undo.removeLast();
    _redo.add(entry);
    _coalesceAllowed = false;
    _notify();
    return true;
  }

  bool redo() {
    if (!canRedo) return false;
    final entry = _redo.last;
    final validation = entry.forward.validate(_document);
    if (validation is CommandFailed) return false;
    _document = entry.forward.applyValidated(_document);
    _redo.removeLast();
    _undo.add(entry);
    _coalesceAllowed = false;
    _notify();
    return true;
  }

  void seal() {
    if (!_coalesceAllowed) return;
    _coalesceAllowed = false;
    _notify();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _group = null;
    _coalesceAllowed = false;
    _notify();
  }

  void reset(DesignDocument document) {
    _document = document;
    clear();
  }

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _trim() {
    while (_undo.length > _limit) {
      _undo.removeAt(0);
    }
  }

  void _notify() {
    if (_listeners.isEmpty) return;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }
}

final class _HistoryEntry {
  _HistoryEntry({
    required this.forward,
    required this.inverse,
    required this.label,
  });

  final DesignCommand forward;
  final DesignCommand inverse;
  final String label;
}

final class _Group {
  _Group({required this.label, required this.startRevision})
    : commands = <DesignCommand>[],
      inverses = <DesignCommand>[];

  final String label;
  final int startRevision;
  final List<DesignCommand> commands;
  final List<DesignCommand> inverses;
}
