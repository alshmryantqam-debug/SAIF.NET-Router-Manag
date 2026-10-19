import 'package:dio/dio.dart';

class RouterOperationGuard extends Interceptor {
  // بما أنك تريد إدارة كاملة، سنسمح بالعمليات ولكن يمكنك تتبعها هنا
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('ROUTER API REQUEST: ${options.method} ${options.path}');
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('ROUTER API ERROR: ${err.message}');
    super.onError(err, handler);
  }
}
