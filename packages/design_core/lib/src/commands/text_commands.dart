import 'package:collection/collection.dart';

import '../document/design_document.dart';
import '../document/text_element.dart';
import 'command_result.dart';
import 'design_command.dart';

final class SetText extends DesignCommand {
  const SetText({required this.element});

  final TextElement element;

  @override
  String get kind => 'setText';

  @override
  CommandResult validate(DesignDocument document) {
    if (element.id.trim().isEmpty) {
      return const CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'text id must not be empty',
        ),
      );
    }
    if (document.spreadById(element.spreadId) == null) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.spreadNotFound,
          message: 'spread "${element.spreadId}" not found',
          targetId: element.spreadId,
        ),
      );
    }
    if (!element.box.isValidUnitRect) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'text box must be a positive rectangle inside 0..1',
          targetId: element.id,
          args: <String, Object?>{'box': element.box.toJson()},
        ),
      );
    }
    if (element.text.length > TextElement.maxTextLength) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'text exceeds ${TextElement.maxTextLength} characters',
          targetId: element.id,
          args: <String, Object?>{'length': element.text.length},
        ),
      );
    }
    if (element.fontSizeNorm <= 0 || element.fontSizeNorm > 0.5) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidValue,
          message: 'fontSizeNorm must be within 0.01..0.5',
          targetId: element.id,
          args: <String, Object?>{'fontSizeNorm': element.fontSizeNorm},
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) {
    final value = element.clamped();
    final index = document.text.indexWhere((element) => element.id == value.id);
    final text = List<TextElement>.of(document.text);
    if (index < 0) {
      text.add(value);
    } else {
      text[index] = value;
    }
    return document.copyWith(text: text);
  }

  @override
  DesignCommand invertCore(DesignDocument preState) {
    final previous = preState.text.firstWhereOrNull(
      (element) => element.id == this.element.id,
    );
    return previous == null
        ? RemoveText(textId: element.id)
        : SetText(element: previous);
  }

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'textId': element.id,
    'spreadId': element.spreadId,
  };

  @override
  String toString() => 'SetText(${element.id} on ${element.spreadId})';
}

final class RemoveText extends DesignCommand {
  const RemoveText({required this.textId});

  final String textId;

  @override
  String get kind => 'removeText';

  @override
  CommandResult validate(DesignDocument document) {
    if (document.text.every((element) => element.id != textId)) {
      return CommandFailed(
        CommandError(
          code: CommandErrorCode.invalidTarget,
          message: 'text "$textId" not found',
          targetId: textId,
        ),
      );
    }
    return const CommandOk();
  }

  @override
  DesignDocument applyCore(DesignDocument document) => document.copyWith(
    text: <TextElement>[
      for (final element in document.text)
        if (element.id != textId) element,
    ],
  );

  @override
  DesignCommand invertCore(DesignDocument preState) => SetText(
    element: preState.text.firstWhere((element) => element.id == textId),
  );

  @override
  Map<String, Object?> describe() => <String, Object?>{
    'kind': kind,
    'textId': textId,
  };

  @override
  String toString() => 'RemoveText($textId)';
}
