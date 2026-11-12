import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_mobile/features/_shared/application/frame_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('analyzer декодирует реальный PNG и считает статистику', (
    tester,
  ) async {
    final stats = await tester.runAsync(() async {
      final source = File('test/fixtures/png/gradient_320x240.png');
      return const IsolateFrameAnalyzer().analyze(source.path);
    });

    expect(stats, isNotNull, reason: 'a PNG must decode on the UI isolate');
    final value = stats!;
    expect(value.sampleCount, greaterThan(0));
    expect(
      value.lumaHistogram.reduce((a, b) => a + b),
      value.sampleCount,
      reason: 'every opaque pixel lands in exactly one bin',
    );
    expect(value.meanR, inInclusiveRange(0, 1));
    expect(value.meanG, inInclusiveRange(0, 1));
    expect(value.meanB, inInclusiveRange(0, 1));
  });

  testWidgets('analyzer не падает на нечитаемом файле', (tester) async {
    final stats = await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('picpac_stats_');
      addTearDown(() => directory.delete(recursive: true));
      final broken = File('${directory.path}/broken.png');
      await broken.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);
      return <Object?>[
        await const IsolateFrameAnalyzer().analyze(broken.path),
        await const IsolateFrameAnalyzer().analyze(
          '${directory.path}/missing.png',
        ),
      ];
    });
    expect(stats, <Object?>[null, null]);
  });
}
