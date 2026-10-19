import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a radio's management UI in the device's browser.
/// Remote URLs must use HTTPS. Local HTTP is allowed for private/LAN management
/// or when the phone is already connected to the site's VPN.
class RadioManagementLauncher {
  const RadioManagementLauncher();

  static bool isSafeManagementUrl(String value, {required bool remote}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
    if (uri.userInfo.isNotEmpty) return false; // never embed credentials in URLs
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    if (remote && uri.scheme != 'https') return false;
    if (uri.hasQuery || uri.hasFragment) return false;
    return true;
  }

  Future<bool> open(String value, {required bool remote}) async {
    final cleaned = value.trim();
    if (!isSafeManagementUrl(cleaned, remote: remote)) {
      throw ArgumentError(
        remote
            ? 'رابط الوصول الخارجي يجب أن يكون HTTPS صالحاً وبدون بيانات دخول داخل الرابط.'
            : 'أدخل رابط إدارة صالحاً يبدأ بـ http:// أو https://.',
      );
    }
    final uri = Uri.parse(cleaned);
    if (kIsWeb) return launchUrl(uri, webOnlyWindowName: '_blank');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
