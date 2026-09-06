import 'package:dio/dio.dart';
import '../logger/app_logger.dart';

/// Custom interceptor for Dio to handle logging and token management.
class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug('NETWORK REQUEST: [${options.method}] ${options.uri}');
    AppLogger.debug('HEADERS: ${options.headers}');
    AppLogger.debug('BODY: ${options.data}');
    
    // TODO: Add Authorization header here from secure storage
    
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.debug('NETWORK RESPONSE: [${response.statusCode}] ${response.requestOptions.uri}');
    AppLogger.debug('DATA: ${response.data}');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      'NETWORK ERROR: [${err.response?.statusCode}] ${err.requestOptions.uri}',
      err,
      err.stackTrace,
    );
    super.onError(err, handler);
  }
}
