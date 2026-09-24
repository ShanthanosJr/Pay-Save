import 'package:dio/dio.dart';

/// Server error in the shape `{ statusCode, code, message }`, or a transport failure.
class ApiException implements Exception {
  ApiException({required this.code, this.statusCode, this.message});

  final String code;
  final int? statusCode;
  final String? message;

  bool get isNetwork => code == 'NETWORK';

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['code'] is String) {
        return ApiException(
          code: data['code'] as String,
          statusCode: error.response?.statusCode,
          message: data['message']?.toString(),
        );
      }
      final status = error.response?.statusCode;
      if (status != null) {
        return ApiException(code: _codeForStatus(status), statusCode: status);
      }
      return ApiException(code: 'NETWORK');
    }
    return ApiException(code: 'UNKNOWN');
  }

  static String _codeForStatus(int status) => switch (status) {
        401 => 'UNAUTHORIZED',
        409 => 'CONFLICT',
        429 => 'TOO_MANY_REQUESTS',
        _ => 'UNKNOWN',
      };

  @override
  String toString() => 'ApiException($code, $statusCode)';
}
