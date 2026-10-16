import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM authenticated encryption for configuration backup payloads.
class EncryptedBackupCodec {
  static final AesGcm _algorithm = AesGcm.with256bits();

  static Future<String> encrypt({
    required List<int> keyBytes,
    required String plaintext,
  }) async {
    if (keyBytes.length != 32) {
      throw ArgumentError.value(keyBytes.length, 'keyBytes', 'AES-256 requires 32 bytes.');
    }
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );
    return jsonEncode({
      'format': 'SAIFNET-ENC-BACKUP',
      'version': 1,
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  static Future<String> decrypt({
    required List<int> keyBytes,
    required String envelope,
  }) async {
    if (keyBytes.length != 32) {
      throw ArgumentError.value(keyBytes.length, 'keyBytes', 'AES-256 requires 32 bytes.');
    }
    final decoded = jsonDecode(envelope);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'SAIFNET-ENC-BACKUP' ||
        decoded['version'] != 1) {
      throw const FormatException('Unsupported or invalid backup envelope.');
    }
    final nonce = base64Decode(decoded['nonce'] as String);
    final ciphertext = base64Decode(decoded['ciphertext'] as String);
    final mac = base64Decode(decoded['mac'] as String);
    final plaintext = await _algorithm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(keyBytes),
    );
    return utf8.decode(plaintext);
  }
}
