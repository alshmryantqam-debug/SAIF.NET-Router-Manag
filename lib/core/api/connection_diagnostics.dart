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
  static Future<DiagResult> run({
    required String host,
    required String user,
    required String pass,
    int? customPort,
  }) async {
    final steps = <DiagStep>[];

    // The binary API is not HTTP REST. Route port 8728 directly to its client.
    if (customPort == 8728) {
      return _tryBinary(host, user, pass, customPort, steps);
    }

    final candidates = <({bool https, int port})>[];
    if (customPort != null) {
      candidates.add((https: true, port: customPort));
      if (customPort != 443) {
        candidates.add((https: false, port: customPort));
      }
    } else {
      candidates
        ..add((https: true, port: 443))
        ..add((https: false, port: 80));
    }

    for (final candidate in candidates) {
      final label = candidate.https ? 'REST عبر HTTPS' : 'REST عبر HTTP';
      try {
        final socket = await Socket.connect(
          host,
          candidate.port,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        steps.add(DiagStep(
          'فحص $label · ${candidate.port}',
          true,
          'المنفذ مفتوح',
        ));
      } catch (_) {
        steps.add(DiagStep(
          'فحص $label · ${candidate.port}',
          false,
          'تعذر الوصول إلى المنفذ ${candidate.port}. تحقق من IP Services والجدار الناري.',
        ));
        continue;
      }

      final client = RestClient(
        host: host,
        user: user,
        pass: pass,
        https: candidate.https,
        port: candidate.port,
      );
      try {
        final dynamic resource = await client.get('system/resource');
        final version = _version(resource);
        steps.add(DiagStep(
          'تسجيل الدخول $label',
          true,
          'تم الاتصال${version.isEmpty ? '' : ' · RouterOS $version'}',
        ));
        return DiagResult(steps, client);
      } on RosException catch (e) {
        steps.add(DiagStep('تسجيل الدخول $label', false, e.message));
        client.close();
      } catch (e) {
        steps.add(DiagStep('تسجيل الدخول $label', false, 'فشل غير متوقع: $e'));
        client.close();
      }
    }

    // A custom non-standard port can be REST or the binary API. Test that
    // same port after REST fails; otherwise RouterOS API defaults to 8728.
    final apiPort = customPort != null &&
            customPort != 80 &&
            customPort != 443
        ? customPort
        : 8728;
    return _tryBinary(host, user, pass, apiPort, steps);
  }

  static String _version(dynamic resource) {
    if (resource is Map) return resource['version']?.toString() ?? '';
    if (resource is List && resource.isNotEmpty && resource.first is Map) {
      return (resource.first as Map)['version']?.toString() ?? '';
    }
    return '';
  }

  static Future<DiagResult> _tryBinary(
    String host,
    String user,
    String pass,
    int port,
    List<DiagStep> steps,
  ) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      steps.add(DiagStep('فحص RouterOS API · $port', true, 'المنفذ مفتوح'));
    } catch (_) {
      steps.add(DiagStep(
        'فحص RouterOS API · $port',
        false,
        'تعذر الوصول. تحقق من IP > Services ومن Available From.',
      ));
      steps.add(const DiagStep(
        'الخلاصة',
        false,
        'لم ينجح الاتصال. تحقق من العنوان والمنفذ وبيانات الدخول وصلاحيات الحساب.',
      ));
      return DiagResult(steps, null);
    }

    final api = ApiClient(host: host, user: user, pass: pass, port: port);
    try {
      final dynamic resource = await api.get('system/resource');
      final version = _version(resource);
      steps.add(DiagStep(
        'تسجيل الدخول عبر API',
        true,
        'تم الاتصال${version.isEmpty ? '' : ' · RouterOS $version'}',
      ));
      return DiagResult(steps, api);
    } on RosException catch (e) {
      steps.add(DiagStep('تسجيل الدخول عبر API', false, e.message));
      api.close();
    } catch (e) {
      steps.add(DiagStep('تسجيل الدخول عبر API', false, 'فشل غير متوقع: $e'));
      api.close();
    }
    steps.add(const DiagStep(
      'الخلاصة',
      false,
      'المنفذ مفتوح لكن تسجيل الدخول فشل. تحقق من بيانات الدخول وصلاحيات الراوتر.',
    ));
    return DiagResult(steps, null);
  }
}