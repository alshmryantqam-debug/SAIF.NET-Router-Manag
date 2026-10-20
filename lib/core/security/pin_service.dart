import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum PinResult { ok, wrong, locked }

class PinService {
  static const _storage = FlutterSecureStorage();
  static final _biometrics = LocalAuthentication();
  static const _maxFails = 5;

  static Future<bool> isSet() async =>
      (await _storage.read(key: 'pin_hash')) != null;

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> setPin(String pin) async {
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await _storage.write(key: 'pin_salt', value: salt);
    await _storage.write(key: 'pin_hash', value: _hash(pin, salt));
    await _storage.write(key: 'pin_fails', value: '0');
    await _storage.delete(key: 'pin_lock_until');
  }

  static Future<Duration?> lockRemaining() async {
    final value = await _storage.read(key: 'pin_lock_until');
    if (value == null) return null;
    final remaining = DateTime.fromMillisecondsSinceEpoch(int.parse(value))
        .difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  static Future<PinResult> verify(String pin) async {
    if (await lockRemaining() != null) return PinResult.locked;
    final salt = await _storage.read(key: 'pin_salt');
    final hash = await _storage.read(key: 'pin_hash');
    if (salt == null || hash == null) return PinResult.wrong;

    if (_hash(pin, salt) == hash) {
      await _storage.write(key: 'pin_fails', value: '0');
      return PinResult.ok;
    }

    final fails = int.parse(await _storage.read(key: 'pin_fails') ?? '0') + 1;
    if (fails >= _maxFails) {
      // قفل يتضاعف مع كل دورة: 30 ثانية ثم دقيقة...
      final seconds = 30 * (1 << ((fails ~/ _maxFails) - 1).clamp(0, 6));
      await _storage.write(
        key: 'pin_lock_until',
        value: DateTime.now()
            .add(Duration(seconds: seconds))
            .millisecondsSinceEpoch
            .toString(),
      );
    }
    await _storage.write(key: 'pin_fails', value: fails.toString());
    return fails >= _maxFails ? PinResult.locked : PinResult.wrong;
  }

  static Future<bool> biometric() async {
    try {
      if (!await _biometrics.canCheckBiometrics) return false;
      return await _biometrics.authenticate(
        localizedReason: 'تأكيد الهوية للدخول إلى SAIF.NET',
        biometricOnly: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
