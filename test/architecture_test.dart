import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final Directory root = Directory.current;
  final Map<String, List<String>> cache = <String, List<String>>{};

  List<String> urisOf(File file) => cache.putIfAbsent(
    file.path,
    () => RegExp(
      r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!).toList(),
  );

  List<File> dartFilesUnder(String dir) {
    final directory = Directory('${root.path}/$dir');
    if (!directory.existsSync()) return const <File>[];
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  String? normalize(String fromPath, String uri) {
    final relativeFrom = fromPath.substring(root.path.length + 1);
    final List<String> segments;
    if (uri.startsWith('package:picpac_mobile/')) {
      segments = uri.substring('package:picpac_mobile/'.length).split('/');
    } else if (uri.startsWith('package:') || uri.startsWith('dart:')) {
      return null;
    } else {
      segments = <String>[
        ...relativeFrom.split('/')..removeLast(),
        ...uri.split('/'),
      ];
    }
    final resolved = <String>[];
    for (final segment in segments) {
      if (segment == '.' || segment.isEmpty) continue;
      if (segment == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
        continue;
      }
      resolved.add(segment);
    }
    return resolved.join('/');
  }

  List<String> violations(
    String dir,
    List<String> forbidden, {
    bool Function(String uri)? except,
  }) {
    final found = <String>[];
    for (final file in dartFilesUnder(dir)) {
      for (final uri in urisOf(file)) {
        if (except != null && except(uri)) continue;
        for (final needle in forbidden) {
          if (uri == needle || uri.startsWith('$needle/')) {
            found.add(
              '${file.path.substring(root.path.length + 1)}: $uri '
              '(запрещён «$needle»)',
            );
          }
        }
      }
    }
    return found;
  }

  group('packages/design_core — чистый Dart', () {
    test('не тянет Flutter, dart:ui, dart:io, HTTP и контракты API', () {
      expect(
        violations('packages/design_core/lib', <String>[
          'package:flutter',
          'package:flutter_test',
          'dart:ui',
          'dart:io',
          'package:http',
          'api_contract',
        ]),
        isEmpty,
        reason:
            'design_core — модель документа, команд и preflight без Flutter',
      );
    });

    test('сканер действительно читает пакет', () {
      expect(dartFilesUnder('packages/design_core/lib'), isNotEmpty);
    });
  });

  group('packages/api_contract — DTO и порты', () {
    test('не тянет Flutter и dio', () {
      expect(
        violations('packages/api_contract/lib', <String>[
          'package:flutter',
          'package:dio',
        ]),
        isEmpty,
        reason:
            'контракт общий для приложения и mock/BFF, UI и клиент — снаружи',
      );
    });

    test('сканер действительно читает пакет', () {
      expect(dartFilesUnder('packages/api_contract/lib'), isNotEmpty);
    });
  });

  group('packages/mock_server — сервер без приложения', () {
    test('не тянет Flutter и код приложения', () {
      expect(
        violations('packages/mock_server/lib', <String>[
          'package:flutter',
          'package:picpac_mobile',
        ]),
        isEmpty,
        reason: 'mock — stateful HTTP-сервер, а не часть UI',
      );
    });

    test('сканер действительно читает пакет', () {
      expect(dartFilesUnder('packages/mock_server/lib'), isNotEmpty);
    });
  });

  group('lib/features — фичи не импортируют друг друга', () {
    test('разрешены только core/app/render/_shared и свои файлы', () {
      final found = <String>[];
      final features = Directory('${root.path}/lib/features')
          .listSync()
          .whereType<Directory>()
          .map((dir) => dir.path.split(Platform.pathSeparator).last)
          .toList();
      expect(features, isNotEmpty);

      for (final owner in features) {
        for (final file in dartFilesUnder('lib/features/$owner')) {
          for (final uri in urisOf(file)) {
            final target = normalize(file.path, uri);
            if (target == null) continue;
            final parts = target.split('/');
            if (parts.length < 4 ||
                parts[0] != 'lib' ||
                parts[1] != 'features') {
              continue;
            }
            final other = parts[2];
            if (other == owner || other == '_shared') continue;
            found.add(
              '${file.path.substring(root.path.length + 1)} -> $other '
              '($uri)',
            );
          }
        }
      }
      expect(
        found,
        isEmpty,
        reason:
            'общее между фичами живёт в _shared/ или app/, иначе фичи '
            'срастаются и вертикальный срез теряет границу',
      );
    });
  });

  group('lib/payments — свой bounded context', () {
    test('не импортирует фичи: общие виджеты живут в core/presentation', () {
      expect(
        violations('lib/payments', <String>['lib/features', 'features']),
        isEmpty,
        reason:
            'платежи не знают о заказах и экранах клиента; общее — только '
            'core и api_contract',
      );
    });

    test('сканер действительно читает платежи', () {
      expect(dartFilesUnder('lib/payments'), isNotEmpty);
    });
  });

  group('lib — один state-менеджер, один DI, один HTTP-клиент', () {
    test('нет flutter_bloc, get_it, provider и shared_preferences', () {
      expect(
        violations('lib', <String>[
          'package:flutter_bloc',
          'package:flutter_redux',
          'package:get_it',
          'package:provider',
          'package:shared_preferences',
        ]),
        isEmpty,
        reason: 'стек: Riverpod + dio + drift; второй экземпляр не добавляем',
      );
    });

    test('сканер видит импорты приложения', () {
      final imported = <String>{};
      for (final file in dartFilesUnder('lib')) {
        imported.addAll(urisOf(file));
      }
      expect(imported, isNotEmpty);
    });
  });
}
