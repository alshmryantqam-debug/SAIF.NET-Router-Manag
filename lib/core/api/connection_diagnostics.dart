import 'dart:io';
import 'router_client.dart';
import 'routeros_client.dart' show RestClient, RosException, RosErrorType;

class DiagStep {
  final String title;
  final bool ok;
  final String detail;
  const DiagStep(this.title, this.ok, this.detail);
}

class DiagResult {
  final List<DiagStep> steps;
  final RouterOsClient? client; // غير null عند النجاح الكامل
  const DiagResult(this.steps, this.client);
  bool get success => client != null;
}

class ConnectionDiagnostics {
  /// يجرّب https ثم http تلقائياً، ويرجع خطوات واضحة تُعرض للمستخدم.
  static Future<DiagResult> run({
    required String host,
    required String user,
    required String pass,
    int? customPort,
  }) async {
    final steps = <DiagStep>[];
    final candidates = <({bool https, int port})>[
      (https: true, port: customPort ?? 443),
      (https: false, port: customPort ?? 80),
    ];

    for (final c in candidates) {
      final label = c.https ? 'HTTPS' : 'HTTP';

      try {
        final s = await Socket.connect(host, c.port, timeout: const Duration(seconds: 5));
        s.destroy();
        steps.add(DiagStep('منفذ $label ${c.port}', true, 'المنفذ مفتوح'));
      } catch (_) {
        steps.add(DiagStep('منفذ $label ${c.port}', false,
            c.https
                ? 'مغلق. فعّل www-ssl من IP > Services، وتأكد أن Available From يسمح بعنوانك'
                : 'مغلق. فعّل خدمة www من IP > Services'));
        continue;
      }

      final client = RestClient(
          host: host, user: user, pass: pass, https: c.https, port: c.port);
      try {
        final res = await client.get('/system/resource');
        final ver = (res is Map ? res['version'] : null) ?? '?';
        steps.add(DiagStep('تسجيل الدخول عبر $label', true, 'RouterOS $ver'));
        return DiagResult(steps, client);
      } on RosException catch (e) {
        steps.add(DiagStep('تسجيل الدخول عبر $label', false, e.message));
        client.close();
        if (e.type == RosErrorType.auth || e.type == RosErrorType.forbidden) {
          return DiagResult(steps, null); // لا فائدة من تجربة بروتوكول آخر
        }
      }
    }
    steps.add(const DiagStep('الخلاصة', false,
        'تحقق أن العنوان قابل للوصول من هاتفك (نفس الشبكة أو عبر WireGuard)'));
    return DiagResult(steps, null);
  }
}
