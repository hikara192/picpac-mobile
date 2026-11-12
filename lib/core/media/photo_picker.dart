import 'package:design_core/design_core.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_format.dart';

final class PickedFile {
  const PickedFile({
    required this.path,
    required this.name,
    this.mimeType,
    required this.bytes,
  });

  final String path;

  final String name;

  final String? mimeType;

  final int bytes;

  @override
  String toString() => 'PickedFile($name, $bytes bytes)';
}

abstract interface class PhotoPickerPort {
  Future<Result<List<PickedFile>>> pickImages({int? limit});

  Future<Result<List<PickedFile>>> recoverLostSelection();
}

final class ImagePickerPhotoPicker implements PhotoPickerPort {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Result<List<PickedFile>>> pickImages({int? limit}) async {
    try {
      final files = await _picker.pickMultiImage(limit: limit);
      return Ok<List<PickedFile>>(await _describe(files));
    } on PlatformException catch (error) {
      return Err<List<PickedFile>>(_mapPlatformError(error));
    } on Object catch (error) {
      return Err<List<PickedFile>>(
        MediaFailure.pickerUnavailable(message: '${error.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<List<PickedFile>>> recoverLostSelection() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return const Ok<List<PickedFile>>(<PickedFile>[]);
      final exception = response.exception;
      if (exception != null) {
        return Err<List<PickedFile>>(_mapPlatformError(exception));
      }
      return Ok<List<PickedFile>>(await _describe(response.files ?? const []));
    } on Object catch (error) {
      return Err<List<PickedFile>>(
        MediaFailure.pickerUnavailable(message: '${error.runtimeType}'),
      );
    }
  }

  Future<List<PickedFile>> _describe(List<XFile> files) async {
    final picked = <PickedFile>[];
    for (final file in files) {
      var bytes = 0;
      try {
        bytes = await file.length();
      } on Object {
        bytes = 0;
      }
      picked.add(
        PickedFile(
          path: file.path,
          name: file.name,
          mimeType: file.mimeType,
          bytes: bytes,
        ),
      );
    }
    return picked;
  }

  MediaFailure _mapPlatformError(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') || code.contains('permission')) {
      return MediaFailure.permissionDenied();
    }
    return MediaFailure.pickerUnavailable(message: error.code);
  }
}
