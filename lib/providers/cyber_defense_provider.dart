import 'package:flutter/foundation.dart';

import 'connection_provider.dart';

class CyberDefenseProvider extends ChangeNotifier {
  final ConnectionProvider connection;

  CyberDefenseProvider(this.connection);

  bool _loading = false;
  bool _applyingArp = false;
  String _error = '';
  String _notice = '';
  List<Map<String, dynamic>> _interfaces = const [];
  List<Map<String, dynamic>> _dhcpServers = const [];
  List<Map<String, dynamic>> _dhcpAlerts = const [];
  String? _selectedInterfaceId;

  bool get isLoading => _loading;
  bool get isApplyingArp => _applyingArp;
  bool get isConnected => connection.isConnected;
  String get error => _error;
  String get notice => _notice;
  List<Map<String, dynamic>> get interfaces => List.unmodifiable(_interfaces);
  List<Map<String, dynamic>> get dhcpServers => List.unmodifiable(_dhcpServers);
  List<Map<String, dynamic>> get dhcpAlerts => List.unmodifiable(_dhcpAlerts);
  String? get selectedInterfaceId => _selectedInterfaceId;

  List<Map<String, dynamic>> get supportedInterfaces => _interfaces
      .where((item) {
        final type = item['type']?.toString();
        return (type == 'bridge' || type == 'ether') &&
            item['.id'] != null &&
            item['name'] != null;
      })
      .toList(growable: false);

  Map<String, dynamic>? get selectedInterface {
    for (final item in supportedInterfaces) {
      if (item['.id']?.toString() == _selectedInterfaceId) return item;
    }
    return null;
  }

  bool get selectedInterfaceIsReplyOnly =>
      selectedInterface?['arp']?.toString() == 'reply-only';

  bool get hasDhcpAlerts => _dhcpAlerts.isNotEmpty;

  Future<void> refresh() async {
    if (_loading) return;
    if (!connection.isConnected) {
      _error = 'اتصل بالراوتر أولاً. لم يتم إجراء أي فحص.';
      _interfaces = const [];
      _dhcpServers = const [];
      _dhcpAlerts = const [];
      notifyListeners();
      return;
    }

    _loading = true;
    _error = '';
    _notice = '';
    notifyListeners();
    try {
      await connection.fetchInterfaces();
      final results = await Future.wait<List<dynamic>>([
        connection.getDhcpServers(),
        connection.getRouterLogs(),
      ]);

      _interfaces = connection.interfaces
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      _dhcpServers = results[0]
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      // These are real RouterOS log entries, not packet-level DHCP snooping.
      // RouterOS logs do not guarantee visibility of every external DHCP offer.
      final suspiciousTerms = <String>[
        'rogue dhcp',
        'unauthorized dhcp',
        'dhcp conflict',
        'duplicate address',
        'dhcp server conflict',
      ];
      _dhcpAlerts = results[1]
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) {
            final message = (row['message'] ?? '').toString().toLowerCase();
            final topics = (row['topics'] ?? '').toString().toLowerCase();
            return topics.contains('dhcp') &&
                suspiciousTerms.any(message.contains);
          })
          .toList(growable: false);

      final supported = supportedInterfaces;
      if (!supported.any((item) => item['.id']?.toString() == _selectedInterfaceId)) {
        _selectedInterfaceId = supported.isEmpty
            ? null
            : supported.first['.id']?.toString();
      }
      _notice = 'تم تحديث بيانات المنافذ وخوادم DHCP وسجل الراوتر. هذا السجل لا يكشف كل عروض DHCP الخارجية.';
    } catch (error) {
      _interfaces = const [];
      _dhcpServers = const [];
      _dhcpAlerts = const [];
      _error = 'تعذر إكمال الفحص من الراوتر: ${_safeError(error)}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectInterface(String? id) {
    _selectedInterfaceId = id;
    notifyListeners();
  }

  Future<bool> enableArpReplyOnly() async {
    final target = selectedInterface;
    if (!connection.isConnected || target == null) {
      _error = 'لا يوجد اتصال أو لم يتم اختيار منفذ صالح.';
      notifyListeners();
      return false;
    }
    if (selectedInterfaceIsReplyOnly) {
      _notice = 'وضع الحماية مضبوط فعلياً على هذا المنفذ وفق قراءة الراوتر.';
      notifyListeners();
      return true;
    }

    _applyingArp = true;
    _error = '';
    _notice = '';
    notifyListeners();
    try {
      final ok = await connection.setInterfaceArpMode(
        id: target['.id'].toString(),
        type: target['type'].toString(),
        mode: 'reply-only',
      );
      if (!ok) {
        _error = 'لم يؤكد الراوتر تطبيق الإعداد. تحقق من الصلاحيات وسجل الأحداث.';
        return false;
      }
      await refresh();
      final updated = selectedInterfaceIsReplyOnly;
      if (!updated) {
        _error = 'لم يظهر وضع الحماية في قراءة التحقق؛ لا يمكن تأكيد نجاح التغيير.';
        return false;
      }
      _notice = 'أكد الراوتر تفعيل وضع الرد فقط على المنفذ المحدد.';
      return true;
    } catch (error) {
      _error = 'تعذر تفعيل الحماية: ${_safeError(error)}';
      return false;
    } finally {
      _applyingArp = false;
      notifyListeners();
    }
  }

  String _safeError(Object error) {
    final value = error.toString();
    return value.length > 180 ? value.substring(0, 180) : value;
  }
}
