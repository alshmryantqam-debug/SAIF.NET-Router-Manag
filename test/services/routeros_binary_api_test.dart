import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/services/routeros_binary_api.dart';

void main() {
  group('RouterOsBinaryApi safety guards', () {
    test('does not send a command without a connection', () async {
      final api = RouterOsBinaryApi();
      await expectLater(
        api.send(['/system/resource/print']),
        throwsA(isA<StateError>()),
      );
    });

    test('list helper rejects non-print commands before connecting', () async {
      final api = RouterOsBinaryApi();
      await expectLater(
        api.getList('/system/script/run'),
        throwsArgumentError,
      );
      await expectLater(
        api.getList('system/resource/print'),
        throwsArgumentError,
      );
    });
  });
}
