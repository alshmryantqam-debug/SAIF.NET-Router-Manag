import 'package:flutter_test/flutter_test.dart';
import 'package:nova_router_manager/models/hotspot_user.dart';
import 'package:nova_router_manager/models/router_config.dart';
import 'package:nova_router_manager/models/voucher.dart';
import 'package:nova_router_manager/services/mikrotik_service.dart';
import 'package:nova_router_manager/services/routeros_binary_api.dart';
import 'package:nova_router_manager/services/routeros_rest_api.dart';

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

  group('Read-only command guard', () {
    test('allows known RouterOS read paths', () {
      expect(MikrotikService.isReadOnlyCommandPath('/ip/hotspot/user'), isTrue);
      expect(MikrotikService.isReadOnlyCommandPath('/system/resource/print'), isTrue);
      expect(MikrotikService.isReadOnlyCommandPath('/ip/service'), isTrue);
    });

    test('rejects commands that could change router state', () {
      expect(MikrotikService.isReadOnlyCommandPath('/system/reboot'), isFalse);
      expect(MikrotikService.isReadOnlyCommandPath('/ip/firewall/filter/remove'), isFalse);
      expect(MikrotikService.isReadOnlyCommandPath('/system/resource?x=y'), isFalse);
    });
  });

  group('RouterOS binary framing', () {
    test('encodes length prefixes at protocol boundaries', () {
      expect(RouterOsBinaryApi.encodeLength(127), [0x7F]);
      expect(RouterOsBinaryApi.encodeLength(128), [0x80, 0x80]);
      expect(RouterOsBinaryApi.encodeLength(16384), [0xC0, 0x40, 0x00]);
    });

    test('terminates each encoded sentence with a zero byte', () {
      final bytes = RouterOsBinaryApi.encodeSentence(['/system/resource/print']);
      expect(bytes.last, 0);
      expect(bytes.length, greaterThan(1));
    });
  });

  group('Local address classification', () {
    test('recognizes private and public IPv4 addresses', () {
      expect(isPrivateHost('192.168.88.1'), isTrue);
      expect(isPrivateHost('10.0.0.1'), isTrue);
      expect(isPrivateHost('8.8.8.8'), isFalse);
    });
  });

}
