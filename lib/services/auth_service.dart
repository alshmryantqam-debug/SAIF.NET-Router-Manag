import 'package:local_auth/local_auth.dart';
class AuthService {final _auth=LocalAuthentication();Future<bool> available() async {try{return await _auth.isDeviceSupported()&&await _auth.canCheckBiometrics;}catch(_){return false;}}Future<bool> authenticate() async {try{return await _auth.authenticate(localizedReason:'أكد هويتك لفتح TikPlus ULTRA');}catch(_){return false;}}}
