import 'dart:io';

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
    if (!remote && uri.scheme == 'http' && !_isPrivateOrLocalHost(uri.host)) {
      return false;
    }
    if (uri.hasQuery || uri.hasFragment) return false;
    return true;
  }

  static bool _isPrivateOrLocalHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' || normalized.endsWith('.local')) return true;
    final address = InternetAddress.tryParse(normalized);
    if (address == null) return false;
    if (address.type == InternetAddressType.IPv6) {
      return address.isLoopback || address.isLinkLocal ||
          (address.rawAddress.isNotEmpty && (address.rawAddress.first & 0xfe) == 0xfc);
    }
    final parts = normalized.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((v) => v == null || v < 0 || v > 255)) return false;
    final a = octets[0]!;
    final b = octets[1]!;
    return a == 10 ||
        a == 127 ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
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
