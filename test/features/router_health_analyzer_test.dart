import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/features/diagnostics/router_health_analyzer.dart';
import 'package:tikplus_ultra/services/mikrotik_service.dart';

void main() {
  const analyzer = RouterHealthAnalyzer();

  SystemResource resources({
    int cpu = 12,
    int freeMemory = 800,
    int totalMemory = 1000,
    int freeHdd = 900,
    int totalHdd = 1000,
  }) =>
      SystemResource(
        cpuLoad: cpu,
        freeMemory: freeMemory,
        totalMemory: totalMemory,
        freeHdd: freeHdd,
        totalHdd: totalHdd,
      );

  InterfaceInfo iface(String name, {bool running = true, bool disabled = false}) =>
      InterfaceInfo(
        id: '*1',
        name: name,
        running: running,
        disabled: disabled,
      );

  test('reports critical CPU and memory pressure', () {
    final findings = analyzer.analyze(
      resources: resources(cpu: 95, freeMemory: 50),
      interfaces: const [],
      queues: const [],
    );

    expect(findings.map((f) => f.code), contains('cpu-critical'));
    expect(findings.map((f) => f.code), contains('memory-critical'));
  });

  test('flags only configured WAN interfaces that are down', () {
    final findings = analyzer.analyze(
      resources: resources(),
      interfaces: [iface('ether1', running: false), iface('ether4', running: false)],
      queues: const [],
      wanInterfaces: {'ether1'},
    );

    expect(findings.map((f) => f.code), contains('wan-down'));
    expect(findings.where((f) => f.code == 'wan-down').single.subject, 'ether1');
  });

  test('warns about explicitly named unlimited queues but not generic 0/0 queues', () {
    final findings = analyzer.analyze(
      resources: resources(),
      interfaces: const [],
      queues: const [
        {'name': 'gerd-speed-open', 'max-limit': '0/0'},
        {'name': 'normal-default', 'max-limit': '0/0'},
      ],
    );

    expect(findings.where((f) => f.code == 'unlimited-queue'), hasLength(1));
    expect(findings.where((f) => f.code == 'unlimited-queue').single.subject,
        'gerd-speed-open');
  });

  test('returns a qualified informational finding when no thresholds are hit', () {
    final findings = analyzer.analyze(
      resources: resources(),
      interfaces: [iface('ether1')],
      queues: const [],
      wanInterfaces: {'ether1'},
    );

    expect(findings, hasLength(1));
    expect(findings.single.code, 'no-findings');
  });
}
