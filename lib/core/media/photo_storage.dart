import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';

import '../app_logger.dart';

abstract interface class PhotoStoragePort {
  Future<Result<void>> putObject({
    required UploadTicket ticket,
    required File file,
    void Function(int sent, int total)? onProgress,
  });
}

final class DioPhotoStorage implements PhotoStoragePort {
  DioPhotoStorage({Dio? dio, this._logger = const AppLogger()}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 120),
            validateStatus: (status) => status != null && status < 400,
          ),
        );
  }

  final AppLogger _logger;
  late final Dio _dio;

  @override
  Future<Result<void>> putObject({
    required UploadTicket ticket,
    required File file,
    void Function(int sent, int total)? onProgress,
  }) async {
    final length = await file.length();
    try {
      await _dio.request<Object?>(
        ticket.url,
        data: file.openRead(),
        options: Options(
          method: ticket.method,
          headers: <String, Object?>{
            ...ticket.headers,
            'content-length': length,
          },
          responseType: ResponseType.json,
        ),
        onSendProgress: onProgress,
      );
      return const Ok<void>(null);
    } on DioException catch (error) {
      final failure = _mapError(error);
      _logger.warning('media.upload.transfer.failed', <String, Object?>{
        'code': failure.code,
        'status': ?failure.statusCode,
      });
      return Err<void>(failure);
    }
  }

  ApiFailure _mapError(DioException error) {
    final response = error.response;
    final data = response?.data;
    if (data is Map) {
      try {
        return ApiFailure.fromJson(Map<String, Object?>.from(data));
      } on Object {
      }
    }
    final status = response?.statusCode;
    if (status != null) {
      return switch (status) {
        401 => const ApiFailure(
          code: ApiErrorCode.unauthorized,
          message: 'unauthorized',
          statusCode: 401,
        ),
        403 => const ApiFailure(
          code: ApiErrorCode.forbidden,
          message: 'forbidden',
          statusCode: 403,
        ),
        410 => const ApiFailure(
          code: 'upload_expired',
          message: 'the upload ticket has expired',
          statusCode: 410,
        ),
        413 => const ApiFailure(
          code: ApiErrorCode.validationFailed,
          message: 'the object is too large',
          statusCode: 413,
        ),
        >= 500 => ApiFailure(
          code: ApiErrorCode.serverError,
          message: 'storage error',
          statusCode: status,
        ),
        _ => ApiFailure(
          code: ApiErrorCode.serverError,
          message: 'unexpected status $status',
          statusCode: status,
        ),
      };
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiFailure.timeout(),
      _ => ApiFailure.networkUnavailable(),
    };
  }
}
