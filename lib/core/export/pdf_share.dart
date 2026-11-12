import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ShareOutcome {
  shared,

  dismissed,

  unavailable,
}

abstract interface class PdfSharePort {
  Future<ShareOutcome> sharePdf({
    required Uint8List bytes,
    required String fileName,
    String? subject,
  });
}

final class SystemPdfShare implements PdfSharePort {
  const SystemPdfShare();

  static const String mimeType = 'application/pdf';

  @override
  Future<ShareOutcome> sharePdf({
    required Uint8List bytes,
    required String fileName,
    String? subject,
  }) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/picpac/exports',
    );
    await directory.create(recursive: true);
    await _dropPreviousExports(directory);

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: mimeType, name: fileName)],
        fileNameOverrides: <String>[fileName],
        subject: subject,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }

  Future<void> _dropPreviousExports(Directory directory) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.endsWith('.pdf')) continue;
        try {
          await entity.delete();
        } on FileSystemException {
        }
      }
    } on FileSystemException {
    }
  }
}
