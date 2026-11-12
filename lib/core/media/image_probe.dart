import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:design_core/design_core.dart';

import 'photo_format.dart';

final class ProbedPhoto {
  const ProbedPhoto({required this.widthPx, required this.heightPx});

  final int widthPx;

  final int heightPx;

  int get longestSide => widthPx > heightPx ? widthPx : heightPx;

  @override
  String toString() => 'ProbedPhoto(${widthPx}x$heightPx)';
}

abstract interface class ImageProbePort {
  Future<Result<ProbedPhoto>> probe(File file);

  Future<ui.Image?> preview(File file);
}

final class UiImageProbe implements ImageProbePort {
  const UiImageProbe();

  @override
  Future<Result<ProbedPhoto>> probe(File file) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 || descriptor.height <= 0) {
        return Err<ProbedPhoto>(
          MediaFailure(
            code: MediaErrorCode.decodeFailed,
            message: 'the image has no pixels',
          ),
        );
      }
      return Ok<ProbedPhoto>(
        ProbedPhoto(widthPx: descriptor.width, heightPx: descriptor.height),
      );
    } on Object catch (error) {
      return Err<ProbedPhoto>(
        MediaFailure(
          code: MediaErrorCode.decodeFailed,
          message: 'the image cannot be decoded: ${error.runtimeType}',
        ),
      );
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  Future<Result<ProbedPhoto>> probeBytes(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 || descriptor.height <= 0) {
        return Err<ProbedPhoto>(
          MediaFailure(
            code: MediaErrorCode.decodeFailed,
            message: 'the image has no pixels',
          ),
        );
      }
      return Ok<ProbedPhoto>(
        ProbedPhoto(widthPx: descriptor.width, heightPx: descriptor.height),
      );
    } on Object catch (error) {
      return Err<ProbedPhoto>(
        MediaFailure(
          code: MediaErrorCode.decodeFailed,
          message: 'the image cannot be decoded: ${error.runtimeType}',
        ),
      );
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  Future<ui.Image?> preview(File file) =>
      decodePreviewFile(file, maxSide: PhotoFormats.previewMaxSide);
}

Future<ui.Image?> decodePreviewFile(
  File file, {
  int maxSide = PhotoFormats.previewMaxSide,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 || descriptor.height <= 0) return null;
    final scale = _scaleFor(descriptor.width, descriptor.height, maxSide);
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, maxSide),
      targetHeight: (descriptor.height * scale).round().clamp(1, maxSide),
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } on Object {
    return null;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

Future<ui.Image?> decodePreview(
  Uint8List bytes, {
  int maxSide = PhotoFormats.previewMaxSide,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 || descriptor.height <= 0) return null;
    final scale = _scaleFor(descriptor.width, descriptor.height, maxSide);
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, maxSide),
      targetHeight: (descriptor.height * scale).round().clamp(1, maxSide),
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } on Object {
    return null;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

double _scaleFor(int width, int height, int maxSide) {
  final longest = width > height ? width : height;
  return longest <= maxSide ? 1.0 : maxSide / longest;
}
