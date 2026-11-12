// Generates `lib/src/seeds.g.dart` from `seeds/*.json`.
//
// Why: the app also runs the mock in-process (`API_MODE=embedded`), where the
// package directory and its JSON files are not on the device filesystem. The
// generated map is the runtime fallback; the JSON files stay the reviewable
// source of truth. `test/seeds_sync_test.dart` fails when the two drift apart.
//
//   dart run tool/embed_seeds.dart
library;

import 'dart:convert';
import 'dart:io';

const String _seedDirectory = 'seeds';
const String _outputPath = 'lib/src/seeds.g.dart';

const List<String> _files = <String>[
  'accounts.json',
  'catalog.json',
  'delivery.json',
  'inspiration.json',
  'payments.json',
  'promotions.json',
];

void main() {
  final directory = Directory(_seedDirectory);
  if (!directory.existsSync()) {
    stderr.writeln('seed directory "$_seedDirectory" not found');
    exitCode = 1;
    return;
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Source: packages/mock_server/seeds/*.json')
    ..writeln('// Regenerate: dart run tool/embed_seeds.dart')
    ..writeln('//')
    ..writeln('// The mock uses these strings when the seed directory is not')
    ..writeln(
      '// reachable (in-process server on a device); the JSON files stay',
    )
    ..writeln('// the reviewable source and are kept in sync by a test.')
    ..writeln('library;')
    ..writeln()
    ..writeln('/// Seed files by name, JSON-encoded exactly as validated.')
    ..writeln(
      'const Map<String, String> embeddedSeedFiles = <String, String>{',
    );

  for (final name in _files) {
    final file = File('$_seedDirectory/$name');
    if (!file.existsSync()) {
      stderr.writeln('missing seed file: ${file.path}');
      exitCode = 1;
      return;
    }
    final raw = file.readAsStringSync();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      stderr.writeln('invalid JSON in ${file.path}: ${error.message}');
      exitCode = 1;
      return;
    }
    if (decoded is! Map<String, Object?>) {
      stderr.writeln('${file.path} must contain a JSON object');
      exitCode = 1;
      return;
    }
    final compact = jsonEncode(decoded);
    if (compact.contains("'''")) {
      stderr.writeln('${file.path} must not contain triple quotes');
      exitCode = 1;
      return;
    }
    buffer
      ..writeln("  '$name': r'''")
      ..writeln(compact)
      ..writeln("''',");
  }

  buffer.writeln('};');

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(buffer.toString());
  stdout.writeln('wrote $_outputPath (${_files.length} files)');
}
