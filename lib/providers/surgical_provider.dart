import 'package:flutter/foundation.dart';
import 'connection_provider.dart';

class TargetUser {
  final String id;
  final String name;
  final String profile;
  final String? callerId;
  final String? activeMac;
  final bool isPppoe;
  final String? activeSessionId;

  const TargetUser({required this.id, required this.name, required this.profile, this.callerId, this.activeMac, required this.isPppoe, this.activeSessionId});

  TargetUser copyWith({String? profile, String? callerId, String? activeSessionId}) => TargetUser(
    id: id, name: name, profile: profile ?? this.profile,
    callerId: callerId ?? this.callerId, activeMac: activeMac,
    isPppoe: isPppoe, activeSessionId: activeSessionId ?? this.activeSessionId,
  );
}

class SurgicalProvider extends ChangeNotifier {
  SurgicalProvider(this._connection);
  final ConnectionProvider _connection;
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  TargetUser? _target;
  TargetUser? get target => _target;
  String _operationLog = 'النظام بانتظار تحديد المشترك.';
  String get operationLog => _operationLog;
  List<String> _profiles = const [];
  List<String> get profiles => _profiles;
  bool _disposed = false;

  void _notify() { if (!_disposed) notifyListeners(); }

  Future<void> loadTarget(String username, bool isPppoe) async {
    final name = username.trim();
    if (name.isEmpty) { _operationLog = 'أدخل اسم المشترك أولاً.'; _target = null; _notify(); return; }
    if (!_connection.isConnected) { _operationLog = 'اتصل بالراوتر أولاً.'; _target = null; _notify(); return; }
    _isProcessing = true; _target = null;
    _operationLog = 'جارٍ البحث في حسابات الراوتر والجلسات النشطة…'; _notify();
    try {
      if (isPppoe) {
        await _connection.fetchPPPoEUsers();
        final users = _connection.pppoeUsers.where((u) => u.name == name).toList();
        if (users.isEmpty) throw Exception('لم يُعثر على حساب برودباند بهذا الاسم.');
        final user = users.first;
        final sessions = await _connection.getActivePPPoESessions();
        final matches = sessions.whereType<Map>().where((s) => (s['name'] ?? '') == name).toList();
        final session = matches.isEmpty ? null : Map<String, dynamic>.from(matches.first);
        _target = TargetUser(id:user.id, name:user.name, profile:user.profile,
          callerId: (session?['caller-id'] ?? user.comment).toString().trim().isEmpty ? null : (session?['caller-id'] ?? user.comment).toString(),
          activeMac: session?['caller-id']?.toString(),
          activeSessionId: session?['.id']?.toString(), isPppoe:true);
      } else {
        await _connection.fetchHotspotUsers();
        final users = _connection.hotspotUsers.where((u) => u.name == name).toList();
        if (users.isEmpty) throw Exception('لم يُعثر على حساب نقطة الاتصال بهذا الاسم.');
        final user = users.first;
        final sessions = await _connection.getActiveHotspotSessions();
        final matches = sessions.whereType<Map>().where((s) => (s['user'] ?? s['name'] ?? '') == name).toList();
        final session = matches.isEmpty ? null : Map<String, dynamic>.from(matches.first);
        final mac = session?['mac-address']?.toString() ?? session?['mac']?.toString();
        _target = TargetUser(id:user.id, name:user.name, profile:user.profile,
          callerId: (user.comment.isEmpty ? null : user.comment),
          activeMac: mac, activeSessionId: session?['.id']?.toString(), isPppoe:false);
      }
      _profiles = (await _connection.getProfiles(pppoe:isPppoe))
        .whereType<Map>().map((p) => (p['name'] ?? '').toString()).where((p) => p.isNotEmpty).toList();
      _operationLog = _target!.activeSessionId == null
        ? 'تم العثور على الحساب، لكن لا توجد جلسة نشطة حالياً.'
        : 'تم العثور على الحساب والجلسة النشطة من الراوتر.';
    } catch (e) {
      _target = null;
      _operationLog = e.toString().replaceFirst('Exception: ', '');
    } finally { _isProcessing = false; _notify(); }
  }

  Future<void> lockMacAddress() async {
    final t = _target;
    if (t == null) return;
    if (t.activeMac == null || t.activeMac!.trim().isEmpty) {
      _operationLog = 'لا توجد جلسة نشطة تحتوي على عنوان جهاز؛ لم يتم إجراء أي تغيير.'; _notify(); return;
    }
    _isProcessing = true; _operationLog = 'جارٍ ربط الحساب بعنوان الجهاز المرصود…'; _notify();
    try {
      if (t.isPppoe) {
        await _connection.updatePppSecret(t.id, {'caller-id': t.activeMac});
      } else {
        await _connection.updateHotspotUser(t.id, {'mac-address': t.activeMac});
      }
      _target = t.copyWith(callerId:t.activeMac);
      _operationLog = 'نجح تقييد الحساب بعنوان الجهاز: ${t.activeMac}';
    } catch(e) { _operationLog = 'فشل تقييد الجهاز: ${e.toString().replaceFirst('Exception: ', '')}'; }
    finally { _isProcessing = false; _notify(); }
  }

  Future<void> atomicProfileShift(String newProfile) async {
    final t = _target;
    if (t == null || newProfile.trim().isEmpty) return;
    if (!_profiles.contains(newProfile)) { _operationLog = 'الباقة المطلوبة غير موجودة على الراوتر؛ أُلغي التنفيذ.'; _notify(); return; }
    _isProcessing = true; _operationLog = 'جارٍ تحديث الباقة…'; _notify();
    var profileChanged = false;
    try {
      if (t.isPppoe) {
        await _connection.updatePppSecret(t.id, {'profile':newProfile});
      } else {
        await _connection.updateHotspotUser(t.id, {'profile':newProfile});
      }
      profileChanged = true;
      _target = t.copyWith(profile:newProfile);
      if (t.activeSessionId == null) {
        _operationLog = 'تغيّرت الباقة بنجاح، لكن لا توجد جلسة نشطة لفصلها.';
        return;
      }
      final removed = t.isPppoe
        ? await _connection.removeActivePPPoESession(t.activeSessionId!)
        : await _connection.removeActiveHotspotSession(t.activeSessionId!);
      if (!removed) throw Exception('لم يؤكد الراوتر فصل الجلسة.');
      _operationLog = 'تم تحديث الباقة وفصل الجلسة لتطبيق الإعداد الجديد.';
    } catch(e) {
      _operationLog = profileChanged
        ? 'تغيّرت الباقة، لكن فشل فصل الجلسة. افحص الجلسات قبل إعادة المحاولة: ${e.toString().replaceFirst('Exception: ', '')}'
        : 'فشل تحديث الباقة؛ لم يتم فصل الجلسة: ${e.toString().replaceFirst('Exception: ', '')}';
    } finally { _isProcessing = false; _notify(); }
  }

  @override
  void dispose() { _disposed = true; super.dispose(); }
}
