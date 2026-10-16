import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/hotspot_user.dart';

void main() {
  group('HotspotUser.fromJson', () {
    test('maps a complete active user', () {
      final user = HotspotUser.fromJson({
        'name': 'voucher-01',
        'profile': '1M',
        'uptime': '1h20m',
        'active': true,
      });

      expect(user.name, 'voucher-01');
      expect(user.profile, '1M');
      expect(user.uptime, '1h20m');
      expect(user.active, isTrue);
    });

    test('uses defaults for absent fields', () {
      final user = HotspotUser.fromJson({});

      expect(user.name, '—');
      expect(user.profile, 'default');
      expect(user.uptime, '—');
      expect(user.active, isFalse);
    });

    test('accepts RouterOS string booleans', () {
      expect(
        HotspotUser.fromJson({'name': 'u', 'active': 'true'}).active,
        isTrue,
      );
      expect(
        HotspotUser.fromJson({'name': 'u', 'active': 'false'}).active,
        isFalse,
      );
    });
  });
}
