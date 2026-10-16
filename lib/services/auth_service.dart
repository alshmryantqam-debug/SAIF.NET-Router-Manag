import 'package:local_auth/local_auth.dart';

/// Biometric / device authentication gate for sensitive actions.
class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> available() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'أكد هويتك لفتح SAIF.NET Router Manager',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
