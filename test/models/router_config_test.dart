import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/router_config.dart';

void main() {
  group('RouterConfigModel', () {
    test('serializes all connection fields', () {
      const config = RouterConfigModel(
        id: 'router-1',
        name: 'Main Router',
        host: '192.0.2.1',
        username: 'operator',
        password: 'secret',
        version: 'v7',
        port: 443,
        ssl: true,
      );

      expect(config.toJson(), {
        'id': 'router-1',
        'name': 'Main Router',
        'host': '192.0.2.1',
        'username': 'operator',
        'password': 'secret',
        'version': 'v7',
        'port': 443,
        'ssl': true,
      });
    });

    test('round-trips through JSON map', () {
      const config = RouterConfigModel(
        id: 'router-2',
        name: 'Backup',
        host: 'router.example.test',
        username: 'readonly',
        password: 'not-a-real-password',
        version: 'v6',
        port: 8729,
        ssl: true,
      );

      expect(
        RouterConfigModel.fromJson(config.toJson()).toJson(),
        config.toJson(),
      );
    });

    test('applies compatibility defaults to missing fields', () {
      final config = RouterConfigModel.fromJson({'host': 'router.test'});

      expect(config.host, 'router.test');
      expect(config.version, 'v7');
      expect(config.port, 8729);
      expect(config.ssl, isTrue);
      expect(config.username, isEmpty);
      expect(config.password, isEmpty);
    });
  });
}
