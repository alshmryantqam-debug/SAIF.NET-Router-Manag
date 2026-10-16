import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/router_config_snapshot.dart';

void main() {
  group('RouterConfigSnapshot', () {
    test('redacts secret fields recursively and inline assignments', () {
      final snapshot = RouterConfigSnapshot.capture(
        id: 'one',
        routerLabel: ' CCR ',
        config: {
          'identity': 'core',
          'password': 'do-not-store',
          'user': {
            'name': 'operator',
            'api-token': 'hidden-too',
          },
          'comment': 'password=embedded-secret mode=router',
        },
      );

      expect(snapshot.routerLabel, 'CCR');
      expect(snapshot.sanitizedConfig['password'], '[REDACTED]');
      expect((snapshot.sanitizedConfig['user'] as Map)['api-token'], '[REDACTED]');
      expect(snapshot.sanitizedConfig['comment'], 'password=[REDACTED] mode=router');
      expect(snapshot.sha256, hasLength(64));
      expect(snapshot.sha256, isNot(contains('do-not-store')));
    });

    test('digest is stable regardless of map key order', () {
      final first = RouterConfigSnapshot.capture(
        id: 'a',
        routerLabel: 'router',
        config: {'b': 2, 'a': 1},
      );
      final second = RouterConfigSnapshot.capture(
        id: 'b',
        routerLabel: 'router',
        config: {'a': 1, 'b': 2},
      );

      expect(first.sha256, second.sha256);
    });

    test('diff reports added, removed and changed fields', () {
      final old = RouterConfigSnapshot.capture(
        id: 'old',
        routerLabel: 'router',
        config: {
          'identity': 'edge-1',
          'system': {'cpu': 10, 'old-field': true},
        },
      );
      final newer = RouterConfigSnapshot.capture(
        id: 'new',
        routerLabel: 'router',
        config: {
          'identity': 'edge-2',
          'system': {'cpu': 25, 'new-field': true},
        },
      );

      final changes = old.diff(newer);
      expect(changes.map((change) => change.path), containsAll([
        'identity',
        'system.cpu',
        'system.old-field',
        'system.new-field',
      ]));
      expect(changes.singleWhere((change) => change.path == 'identity').kind,
          RouterConfigChangeKind.changed);
      expect(changes.singleWhere((change) => change.path == 'system.old-field').kind,
          RouterConfigChangeKind.removed);
      expect(changes.singleWhere((change) => change.path == 'system.new-field').kind,
          RouterConfigChangeKind.added);
    });
  });
}
