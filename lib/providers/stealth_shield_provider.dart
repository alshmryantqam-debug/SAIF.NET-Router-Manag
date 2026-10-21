import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'connection_provider.dart';

/// Applies an explicitly requested WAN MAC/TTL configuration through the
/// currently connected RouterOS REST session. Changes are verified by reading
/// the router back; no simulated success is reported.
class StealthShieldProvider extends ChangeNotifier {
  final ConnectionProvider connection;

  StealthShieldProvider(this.connection);

  bool _isCloaking = false;
  bool get isCloaking => _isCloaking;

  bool _isShieldActive = false;
  bool get isShieldActive => _isShieldActive;
  bool get canRestore => _originalMac != null && _interfaceName != null;

  String _terminalLog = 'النظام جاهز. اتصل بالراوتر قبل تنفيذ أي تغيير.';
  String get terminalLog => _terminalLog;

  String? _interfaceName;
  String? _originalMac;
  String? _appliedMac;

  static const String _ruleComment = 'NOVA_WAN_TTL_SHIELD';

  Future<void> executeCloakingProtocol(String wanInterface, String fakeMac) async {
    if (_isCloaking) return;
    final name = wanInterface.trim();
    final mac = fakeMac.trim().toUpperCase();
    final dio = connection.dio;

    if (!connection.isConnected || dio == null) {
      _setLog('فشل: اتصل بالراوتر أولاً. لم يتم تغيير أي إعداد.');
      return;
    }
    if (name.isEmpty || name.length > 32 || name.contains(RegExp(r'[^A-Za-z0-9_.-]'))) {
      _setLog('اسم المنفذ غير صالح.');
      return;
    }
    if (!RegExp(r'^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(mac) ||
        mac == '00:00:00:00:00:00' ||
        (int.tryParse(mac.substring(0, 2), radix: 16)! & 1) == 1) {
      _setLog('عنوان MAC غير صالح أو عنوان multicast. أدخل عنوان unicast صحيحاً.');
      return;
    }

    _isCloaking = true;
    _terminalLog = 'جارٍ قراءة إعدادات $name والتحقق من قاعدة TTL...';
    notifyListeners();
    try {
      final response = await dio.get<dynamic>('interface/ethernet');
      final rows = _asRows(response.data);
      final target = _firstWhereOrNull(rows, (row) => row['name']?.toString() == name);
      if (target == null || target['.id'] == null) {
        throw Exception('لم يتم العثور على منفذ Ethernet باسم $name.');
      }
      final currentMac = target['mac-address']?.toString();
      if (currentMac == null || currentMac.isEmpty) {
        throw Exception('لم يستطع الراوتر إرجاع MAC الحالي؛ أُوقف التغيير حفاظاً على إمكانية الاستعادة.');
      }
      if (currentMac.toUpperCase() == mac) {
        throw Exception('MAC المدخل يطابق العنوان الحالي بالفعل.');
      }

      // Keep the rollback data before the first write so a partial failure
      // can still be reversed from the screen.
      _interfaceName = name;
      _originalMac = currentMac;
      _appliedMac = mac;
      _terminalLog = 'جارٍ تطبيق MAC على $name. قد ينقطع اتصال الإدارة عبر هذا المنفذ.';
      notifyListeners();
      await dio.post<dynamic>('interface/ethernet/set', data: {
        'numbers': name,
        'mac-address': mac,
      });

      final rulesResponse = await dio.get<dynamic>('ip/firewall/mangle');
      final existing = _asRows(rulesResponse.data).where(
        (row) => row['comment']?.toString() == _ruleComment,
      );
      for (final rule in existing) {
        final id = rule['.id']?.toString();
        if (id != null && id.isNotEmpty) {
          await dio.post<dynamic>('ip/firewall/mangle/remove', data: {'numbers': id});
        }
      }
      await dio.post<dynamic>('ip/firewall/mangle/add', data: {
        'chain': 'postrouting',
        'action': 'change-ttl',
        'new-ttl': 'set:65',
        'passthrough': 'yes',
        'out-interface': name,
        'comment': _ruleComment,
      });

      final verifyInterfaces = _asRows((await dio.get<dynamic>('interface/ethernet')).data);
      final verified = _firstWhereOrNull(verifyInterfaces, (row) => row['name']?.toString() == name);
      final verifyRules = _asRows((await dio.get<dynamic>('ip/firewall/mangle')).data);
      final ruleExists = verifyRules.any((row) =>
          row['comment']?.toString() == _ruleComment &&
          row['action']?.toString() == 'change-ttl' &&
          row['new-ttl']?.toString() == 'set:65' &&
          row['out-interface']?.toString() == name &&
          row['disabled']?.toString() != 'true');
      if (verified?['mac-address']?.toString().toUpperCase() != mac || !ruleExists) {
        throw Exception('لم يؤكد التحقق النهائي تطبيق كل الإعدادات. افحص إعدادات الراوتر قبل إعادة المحاولة.');
      }

      _isShieldActive = true;
      _terminalLog = 'أكد الراوتر تغيير MAC وإضافة قاعدة TTL=65 على $name. هذا لا يضمن إخفاء الراوتر عن مزود الخدمة.';
    } catch (error) {
      _terminalLog = 'فشل التنفيذ أو التحقق: ${_safeError(error)}. افحص المنفذ وقواعد Mangle يدوياً قبل إعادة المحاولة.';
      _isShieldActive = false;
    } finally {
      _isCloaking = false;
      notifyListeners();
    }
  }

  Future<void> disableCloakingProtocol(String wanInterface) async {
    if (_isCloaking) return;
    final name = wanInterface.trim();
    final dio = connection.dio;
    if (!connection.isConnected || dio == null) {
      _setLog('فشل الاستعادة: اتصل بالراوتر أولاً.');
      return;
    }
    if (_interfaceName != null && name != _interfaceName) {
      _setLog('اسم المنفذ لا يطابق المنفذ الذي عدّله هذا التطبيق. استخدم $_interfaceName للاستعادة.');
      return;
    }
    if (_originalMac == null || _interfaceName == null) {
      _setLog('لا توجد قيمة MAC أصلية محفوظة في جلسة التطبيق. لن أخمّنها أو أستخدم reset-mac؛ استعد MAC الأصلي يدوياً من نسخة إعدادات موثوقة.');
      return;
    }

    _isCloaking = true;
    _terminalLog = 'جارٍ إزالة قاعدة TTL واستعادة MAC الأصلي على $name...';
    notifyListeners();
    try {
      final rules = _asRows((await dio.get<dynamic>('ip/firewall/mangle')).data);
      for (final rule in rules.where((row) => row['comment']?.toString() == _ruleComment)) {
        final id = rule['.id']?.toString();
        if (id != null && id.isNotEmpty) {
          await dio.post<dynamic>('ip/firewall/mangle/remove', data: {'numbers': id});
        }
      }

      await dio.post<dynamic>('interface/ethernet/set', data: {
        'numbers': name,
        'mac-address': _originalMac,
      });

      final interfaces = _asRows((await dio.get<dynamic>('interface/ethernet')).data);
      final current = _firstWhereOrNull(interfaces, (row) => row['name']?.toString() == name);
      final remainingRules = _asRows((await dio.get<dynamic>('ip/firewall/mangle')).data)
          .any((row) => row['comment']?.toString() == _ruleComment);
      if (current?['mac-address']?.toString().toUpperCase() != _originalMac!.toUpperCase() ||
          remainingRules) {
        throw Exception('لم يؤكد الراوتر استعادة MAC أو إزالة قاعدة TTL.');
      }

      _isShieldActive = false;
      _interfaceName = null;
      _originalMac = null;
      _appliedMac = null;
      _terminalLog = 'تم التحقق من إزالة قاعدة TTL واستعادة MAC الذي قرأه التطبيق قبل التغيير.';
    } catch (error) {
      _terminalLog = 'تعذرت الاستعادة الكاملة: ${_safeError(error)}. قد يكون جزء من الإعداد قد تغيّر؛ افحص الراوتر قبل المتابعة.';
    } finally {
      _isCloaking = false;
      notifyListeners();
    }
  }

  void _setLog(String value) {
    _terminalLog = value;
    notifyListeners();
  }

  List<Map<String, dynamic>> _asRows(dynamic data) {
    if (data is! List) return const [];
    return data.whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Map<String, dynamic>? _firstWhereOrNull(
    List<Map<String, dynamic>> rows,
    bool Function(Map<String, dynamic>) test,
  ) {
    for (final row in rows) {
      if (test(row)) return row;
    }
    return null;
  }

  String _safeError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return error.message ?? 'خطأ اتصال RouterOS';
    }
    final value = error.toString().replaceFirst('Exception: ', '');
    return value.length > 220 ? value.substring(0, 220) : value;
  }
}
