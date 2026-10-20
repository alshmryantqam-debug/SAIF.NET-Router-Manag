import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum PinResult { ok, wrong, locked }

class PinService {
  static const _s = FlutterSecureStorage();
  static final _bio = LocalAuthentication();
  static const _maxFails = 5;

  static Future<bool> isSet() async => (await _s.read(key: 'pin_hash')) != null;

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static Future<void> setPin(String pin) async {
    final salt = base64Url.encode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    await _s.write(key: 'pin_salt', value: salt);
    await _s.write(key: 'pin_hash', value: _hash(pin, salt));
    await _s.write(key: 'pin_fails', value: '0');
    await _s.delete(key: 'pin_lock_until');
  }

  static Future<Duration?> lockRemaining() async {
    final v = await _s.read(key: 'pin_lock_until');
    if (v == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(int.parse(v))
        .difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  static Future<PinResult> verify(String pin) async {
    if (await lockRemaining() != null) return PinResult.locked;
    final salt = await _s.read(key: 'pin_salt');
    final hash = await _s.read(key: 'pin_hash');
    if (salt == null || hash == null) return PinResult.wrong;

    if (_hash(pin, salt) == hash) {
      await _s.write(key: 'pin_fails', value: '0');
      return PinResult.ok;
    }
    final fails = int.parse(await _s.read(key: 'pin_fails') ?? '0') + 1;
    if (fails >= _maxFails) {
      // قفل يتضاعف مع كل دورة: 30 ثانية ثم دقيقة...
      final secs = 30 * (1 << ((fails ~/ _maxFails) - 1).clamp(0, 6));
      await _s.write(
          key: 'pin_lock_until',
          value: DateTime.now()
              .add(Duration(seconds: secs))
              .millisecondsSinceEpoch
              .toString());
    }
    await _s.write(key: 'pin_fails', value: fails.toString());
    return fails >= _maxFails ? PinResult.locked : PinResult.wrong;
  }

  static Future<bool> biometric() async {
    try {
      if (!await _bio.canCheckBiometrics) return false;
      return await _bio.authenticate(
        localizedReason: 'تأكيد الهوية للدخول إلى SAIF.NET',
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (_) {
      return false;
    }
  }
}
