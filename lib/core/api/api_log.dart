import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiLogEntry {
  final DateTime time;
  final String method;
  final String path;
  final int? status;
  final int ms;
  final String? error;
  const ApiLogEntry(this.time, this.method, this.path, this.status, this.ms, this.error);
  bool get ok => error == null && (status ?? 200) < 400;
}
class ApiLog extends ChangeNotifier {
  static final ApiLog I = ApiLog._();
  ApiLog._();
  final List<ApiLogEntry> entries = [];
  void add(ApiLogEntry e) {
    entries.insert(0, e);
    if (entries.length > 200) entries.removeLast();
    notifyListeners();
  }
  void clear() { entries.clear(); notifyListeners(); }
}
class NovaLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    o.extra['t'] = DateTime.now().millisecondsSinceEpoch;
    h.next(o);
  }
  @override
  void onResponse(Response r, ResponseInterceptorHandler h) {
    if (!r.requestOptions.path.contains('monitor-traffic')) _log(r.requestOptions, r.statusCode, null);
    h.next(r);
  }
  @override
  void onError(DioException e, ErrorInterceptorHandler h) {
    final body = e.response?.data;
    _log(e.requestOptions, e.response?.statusCode, '${e.type.name}${body != null ? ': $body' : ''}');
    h.next(e);
  }
  void _log(RequestOptions o, int? s, String? err) {
    final t0 = (o.extra['t'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    ApiLog.I.add(ApiLogEntry(DateTime.now(), o.method, o.path, s, DateTime.now().millisecondsSinceEpoch - t0, err));
  }
}