import 'dart:io';
import 'api_client.dart';
import 'router_client.dart';
import 'routeros_client.dart' show RestClient, RosException;

class DiagStep {
  final String title;
  final bool ok;
  final String detail;
  const DiagStep(this.title, this.ok, this.detail);
}

class DiagResult {
  final List<DiagStep> steps;
  final RouterOsClient? client;
  const DiagResult(this.steps, this.client);
  bool get success => client != null;
}

class ConnectionDiagnostics {
  /// Tries REST HTTPS:443, REST HTTP:80, then binary API:8728.
  static Future<DiagResult> run({
    required String host,
    required String user,
    required String pass,
    int? customPort,
  }) async {
    final steps = <DiagStep>[];
    final candidates = <({bool https, int port})>[
      (https: true, port: 443),
      (https: false, port: 80),
    ];

    for (final c in candidates) {
      final label = c.https ? 'REST عبر HTTPS' : 'REST عبر HTTP';
      try {
        final socket = await Socket.connect(host, c.port, timeout: const Duration(seconds: 5));
        socket.destroy();
        steps.add(DiagStep('فحص $label · ${c.port}', true, 'المنفذ مفتوح'));
      } catch (_) {
        steps.add(DiagStep('فحص $label · ${c.port}', false,
          c.https
            ? 'تعذر الوصول. تحقق من www-ssl ضمن IP > Services'
            : 'تعذر الوصول. تحقق من www ضمن IP > Services'));
        continue;
      }

      final client = RestClient(host: host, user: user, pass: pass, https: c.https, port: c.port);
      try {
        final dynamic resource = await client.get('system/resource');
        final version = resource is Map ? resource['version']?.toString() : null;
        steps.add(DiagStep('تسجيل الدخول $label', true,
          'تم الاتصال${version == null ? '' : ' · RouterOS $version'}'));
        return DiagResult(steps, client);
      } on RosException catch (e) {
        steps.add(DiagStep('تسجيل الدخول $label', false, e.message));
        client.close();
      } catch (e) {
        steps.add(DiagStep('تسجيل الدخول $label', false, 'فشل غير متوقع: $e'));
        client.close();
      }
    }

    try {
      final socket = await Socket.connect(host, 8728, timeout: const Duration(seconds: 5));
      socket.destroy();
      steps.add(const DiagStep('فحص RouterOS API · 8728', true, 'المنفذ مفتوح'));
    } catch (_) {
      steps.add(const DiagStep('فحص RouterOS API · 8728', false,
        'تعذر الوصول. فعّل خدمة api من IP > Services وتأكد من Available From'));
      steps.add(const DiagStep('الخلاصة', false,
        'لم ينجح REST أو API. تحقق من العنوان والصلاحيات وإعدادات الخدمات.'));
      return DiagResult(steps, null);
    }

    final api = ApiClient(host: host, user: user, pass: pass, port: 8728);
    try {
      await api.connect();
      final dynamic resource = await api.get('system/resource');
      final version = resource is Map ? resource['version']?.toString() : null;
      steps.add(DiagStep('تسجيل الدخول عبر API', true,
        'تم الاتصال${version == null ? '' : ' · RouterOS $version'}'));
      return DiagResult(steps, api);
    } on RosException catch (e) {
      steps.add(DiagStep('تسجيل الدخول عبر API', false, e.message));
      api.close();
    } catch (e) {
      steps.add(DiagStep('تسجيل الدخول عبر API', false, 'فشل غير متوقع: $e'));
      api.close();
    }

    steps.add(const DiagStep('الخلاصة', false,
      'تعذر الاتصال عبر البروتوكولات الثلاثة. تحقق من بيانات الدخول والخدمات المفعّلة.'));
    return DiagResult(steps, null);
  }
}
