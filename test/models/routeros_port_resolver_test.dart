import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/routeros_port_resolver.dart';

void main() {
  group('RouterOsPortResolver', () {
    test('maps conventional ports to secure REST and Binary defaults', () {
      for (final port in [80, 443, 8728, 8729]) {
        expect(RouterOsPortResolver.restPort(configuredPort: port, tls: true), 443);
        expect(RouterOsPortResolver.restPort(configuredPort: port, tls: false), 80);
        expect(RouterOsPortResolver.binaryPort(configuredPort: port, tls: true), 8729);
        expect(RouterOsPortResolver.binaryPort(configuredPort: port, tls: false), 8728);
      }
    });

    test('preserves custom ports', () {
      expect(RouterOsPortResolver.restPort(configuredPort: 8443, tls: true), 8443);
      expect(RouterOsPortResolver.binaryPort(configuredPort: 9000, tls: true), 9000);
    });
  });
}
