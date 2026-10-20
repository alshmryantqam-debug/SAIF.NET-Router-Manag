import 'package:flutter/foundation.dart';
import '../core/api/routeros_client.dart';
import '../models/subscriber.dart';

enum SubFilter { all, online, offline, expired, expiringSoon, disabled }

class SubscribersProvider extends ChangeNotifier {
  RouterOsClient? _client;
  List<Subscriber> all = [];
  List<String> profiles = [];
  bool loading = false;
  String? error;
  String query = '';
  SubFilter filter = SubFilter.all;

  void attach(RouterOsClient? c) {
    if (identical(c, _client)) return;
    _client = c;
    if (c != null) load();
  }

  Future<void> load() async {
    if (_client == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await Future.wait([
        _client!.get('/ppp/secret'),
        _client!.get('/ppp/active'),
        _client!.get('/ppp/profile'),
      ]);
      final active = {for (final a in res[1] as List) a['name']: a};
      all = (res[0] as List)
          .map((s) => Subscriber.fromRos(s, active[s['name']]))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      profiles = (res[2] as List).map((p) => p['name'] as String).toList();
    } on RosException catch (e) {
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  List<Subscriber> get visible {
    return all.where((s) {
      final q = query.trim().toLowerCase();
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !(s.phone ?? '').contains(q)) return false;
      switch (filter) {
        case SubFilter.all:
          return true;
        case SubFilter.online:
          return s.online;
        case SubFilter.offline:
          return !s.online;
        case SubFilter.expired:
          return s.expired;
        case SubFilter.expiringSoon:
          return !s.expired && s.daysLeft != null && s.daysLeft! <= 3;
        case SubFilter.disabled:
          return s.disabled;
      }
    }).toList();
  }

  void setQuery(String v) { query = v; notifyListeners(); }
  void setFilter(SubFilter f) { filter = f; notifyListeners(); }

  Future<void> add({
    required String name,
    required String password,
    required String profile,
    String? phone,
    int? price,
    int months = 1,
  }) async {
    final exp = DateTime.now().add(Duration(days: 30 * months));
    await _client!.put('/ppp/secret', {
      'name': name,
      'password': password,
      'profile': profile,
      'service': 'pppoe',
      'comment': Subscriber.buildComment(expiry: exp, phone: phone, price: price),
    });
    await load();
  }

  Future<void> setDisabled(Subscriber s, bool disabled) async {
    await _client!.patch('/ppp/secret/${s.id}', {'disabled': disabled ? 'true' : 'false'});
    if (disabled && s.activeId != null) await kick(s, reload: false);
    await load();
  }

  Future<void> kick(Subscriber s, {bool reload = true}) async {
    if (s.activeId == null) return;
    await _client!.delete('/ppp/active/${s.activeId}');
    if (reload) await load();
  }

  /// تمديد: يبدأ من تاريخ الانتهاء إن كان في المستقبل، وإلا من اليوم. ويعيد التفعيل.
  Future<void> extend(Subscriber s, {int months = 1}) async {
    final base = (s.expiry != null && s.expiry!.isAfter(DateTime.now()))
        ? s.expiry!
        : DateTime.now();
    final newExp = base.add(Duration(days: 30 * months));
    await _client!.patch('/ppp/secret/${s.id}', {
      'disabled': 'false',
      'comment': Subscriber.buildComment(
          expiry: newExp, phone: s.phone, price: s.price),
    });
    await load();
  }

  Future<void> remove(Subscriber s) async {
    await kick(s, reload: false);
    await _client!.delete('/ppp/secret/${s.id}');
    await load();
  }

  Future<void> changeProfile(Subscriber s, String profile) async {
    await _client!.patch('/ppp/secret/${s.id}', {'profile': profile});
    if (s.activeId != null) await kick(s, reload: false); // ليأخذ السرعة الجديدة
    await load();
  }

  // إحصاءات للوحة القيادة
  int get onlineCount => all.where((s) => s.online).length;
  int get expiredCount => all.where((s) => s.expired).length;
  int get expectedRevenue => all.fold(0, (a, s) => a + (s.price ?? 0));
}
