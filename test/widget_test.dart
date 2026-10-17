import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/hotspot_user.dart';
import 'package:tikplus_ultra/models/router_config.dart';
import 'package:tikplus_ultra/models/voucher.dart';

void main() {
  group('Router profile', () {
    test('round trips connection settings', () {
      final profile = RouterProfile(
        id: 'router-1',
        name: 'Main',
        host: '192.168.88.1',
        username: 'admin',
        password: 'secret',
        restPort: 443,
        apiPort: 8728,
        version: RouterVersion.v7,
        useSsl: true,
      );
      final restored = RouterProfile.fromJson(profile.toJson());
      expect(restored.host, '192.168.88.1');
      expect(restored.restPort, 443);
      expect(restored.version, RouterVersion.v7);
      expect(restored.useSsl, isTrue);
    });
  });

  test('hotspot user maps fields to RouterOS parameters', () {
    final params = const HotspotUser(
      name: 'client01',
      password: '1234',
      profile: 'P1',
      limitUptime: '1d',
    ).toParams();
    expect(params['name'], 'client01');
    expect(params['profile'], 'P1');
    expect(params['limit-uptime'], '1d');
  });

  test('voucher generator creates requested count', () {
    final vouchers = VoucherGenerator.generate(
      count: 12, nameLength: 6, passwordLength: 4, numericOnly: true,
    );
    expect(vouchers, hasLength(12));
    expect(vouchers.every((v) => v.username.length == 6), isTrue);
    expect(vouchers.every((v) => v.password.length == 4), isTrue);
  });
}
