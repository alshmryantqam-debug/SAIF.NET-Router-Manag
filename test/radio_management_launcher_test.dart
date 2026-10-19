import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/services/radio_management_launcher.dart';

void main() {
  group('RadioManagementLauncher URL validation', () {
    test('allows private LAN HTTP and HTTPS URLs', () {
      expect(RadioManagementLauncher.isSafeManagementUrl('http://192.168.1.20', remote: false), isTrue);
      expect(RadioManagementLauncher.isSafeManagementUrl('https://radio.example.com', remote: false), isTrue);
    });
    test('requires HTTPS for remote links', () {
      expect(RadioManagementLauncher.isSafeManagementUrl('http://radio.example.com', remote: true), isFalse);
      expect(RadioManagementLauncher.isSafeManagementUrl('https://radio.example.com', remote: true), isTrue);
    });
    test('rejects embedded credentials and URL query parameters', () {
      expect(RadioManagementLauncher.isSafeManagementUrl('http://user:pass@192.168.1.20', remote: false), isFalse);
      expect(RadioManagementLauncher.isSafeManagementUrl('https://radio.example.com/?password=x', remote: true), isFalse);
    });
    test('rejects public HTTP for local management', () {
      expect(RadioManagementLauncher.isSafeManagementUrl('http://radio.example.com', remote: false), isFalse);
    });
  });
}
