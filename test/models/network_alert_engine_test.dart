import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/network_alert_engine.dart';

void main() {
  group('NetworkAlertEngine', () {
    test('detects a down WAN interface without changing it', () {
      final alerts = NetworkAlertEngine.evaluate(
        interfaceListMembers: [{'list': 'WAN', 'interface': 'ether1'}],
        interfaces: [{'name': 'ether1', 'running': 'false', 'disabled': 'false'}],
        cpuPercent: 20,
        memoryPercent: 30,
        temperatureCelsius: 40,
      );
      expect(alerts.any((a) => a.code == 'wan-down:ether1'), isTrue);
      expect(alerts.where((a) => a.severity == NetworkAlertSeverity.critical), hasLength(1));
    });

    test('does not report a disabled WAN as a link failure', () {
      final alerts = NetworkAlertEngine.evaluate(
        interfaceListMembers: [{'list': 'WAN', 'interface': 'ether2'}],
        interfaces: [{'name': 'ether2', 'running': 'false', 'disabled': 'true'}],
        cpuPercent: 20,
        memoryPercent: 30,
        temperatureCelsius: 40,
      );
      expect(alerts.any((a) => a.code.startsWith('wan-down:')), isFalse);
    });

    test('missing measurements are explicitly unknown', () {
      final alerts = NetworkAlertEngine.evaluate(
        interfaces: const [],
        interfaceListMembers: const [],
      );
      expect(alerts.any((a) => a.code == 'wan-members-unknown'), isTrue);
      expect(alerts.any((a) => a.code == 'cpu-unknown'), isTrue);
      expect(alerts.any((a) => a.code == 'memory-unknown'), isTrue);
    });

    test('CPU, memory and temperature thresholds produce warnings', () {
      final alerts = NetworkAlertEngine.evaluate(
        interfaces: const [],
        interfaceListMembers: const [],
        cpuPercent: 80,
        memoryPercent: 85,
        temperatureCelsius: 78,
      );
      expect(alerts.any((a) => a.code == 'cpu-warning'), isTrue);
      expect(alerts.any((a) => a.code == 'memory-warning'), isTrue);
      expect(alerts.any((a) => a.code == 'temperature-warning'), isTrue);
    });
  });
}
