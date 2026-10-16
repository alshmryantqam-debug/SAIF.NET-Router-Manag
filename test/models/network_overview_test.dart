import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/network_overview.dart';

void main() {
  group('NetworkOverview', () {
    test('counts running interfaces and inventories accurately', () {
      final result = NetworkOverview.fromRows(
        interfaces: [
          {'name': 'ether1', 'running': 'true'},
          {'name': 'ether2', 'running': 'false'},
          {'name': 'bridge1', 'running': 'yes'},
          {'name': 'vlan1'},
        ],
        hotspotActive: [{'user': 'h1'}, {'user': 'h2'}],
        pppActive: [{'name': 'p1'}],
        dhcpLeases: [{'address': '10.0.0.2'}, {'address': '10.0.0.3'}],
        simpleQueues: [{'name': 'q1'}],
      );

      expect(result.interfacesTotal, 4);
      expect(result.interfacesRunning, 2);
      expect(result.hotspotSessions, 2);
      expect(result.pppSessions, 1);
      expect(result.dhcpLeases, 2);
      expect(result.simpleQueues, 1);
    });

    test('empty or unavailable inventories are not fabricated', () {
      final result = NetworkOverview.fromRows(
        interfaces: const [],
        hotspotActive: const [],
        pppActive: const [],
        dhcpLeases: const [],
        simpleQueues: const [],
      );
      expect(result.interfacesTotal, 0);
      expect(result.interfacesRunning, 0);
      expect(result.hotspotSessions, 0);
    });
  });
}
