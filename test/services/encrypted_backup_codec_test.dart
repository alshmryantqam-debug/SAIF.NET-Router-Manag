import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/services/encrypted_backup_codec.dart';

void main() {
  group('EncryptedBackupCodec', () {
    final key = List<int>.generate(32, (index) => index);

    test('encrypts and decrypts a sensitive configuration payload', () async {
      const original = '/system identity set name=core\n/user add name=operator password=secret-value';
      final encrypted = await EncryptedBackupCodec.encrypt(
        keyBytes: key,
        plaintext: original,
      );
      expect(encrypted, isNot(contains('secret-value')));
      expect(encrypted, isNot(contains('/system identity')));
      expect(await EncryptedBackupCodec.decrypt(keyBytes: key, envelope: encrypted), original);
    });

    test('rejects tampering through authenticated encryption', () async {
      final envelope = jsonDecode(await EncryptedBackupCodec.encrypt(
        keyBytes: key,
        plaintext: 'router config',
      )) as Map<String, dynamic>;
      final bytes = base64Decode(envelope['ciphertext'] as String);
      bytes[0] ^= 1;
      envelope['ciphertext'] = base64Encode(bytes);
      await expectLater(
        EncryptedBackupCodec.decrypt(keyBytes: key, envelope: jsonEncode(envelope)),
        throwsA(anything),
      );
    });

    test('rejects wrong key lengths and unsupported formats', () async {
      await expectLater(
        EncryptedBackupCodec.encrypt(keyBytes: [1, 2], plaintext: 'x'),
        throwsArgumentError,
      );
      await expectLater(
        EncryptedBackupCodec.decrypt(keyBytes: key, envelope: '{"format":"other","version":1}'),
        throwsFormatException,
      );
    });
  });
}
