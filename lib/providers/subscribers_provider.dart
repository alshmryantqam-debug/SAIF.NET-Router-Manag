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

  void attach(RouterOsClient? client) {
    if (identical(client, _client)) return;
    _client = client;
    if (client != null) {
      load();
    } else {
      all = [];
      profiles = [];
      error = null;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    final client = _client;
    if (client == null) {
      error = 'اتصل بالراوتر أولاً.';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        client.get('/ppp/secret'),
        client.get('/ppp/active'),
        client.get('/ppp/profile'),
      ]);
      final active = <String, Map>{};
      for (final item in results[1] as List) {
        if (item is Map && item['name'] != null) active[item['name'].toString()] = item;
      }
      all = (results[0] as List).whereType<Map>().map((secret) =>
        Subscriber.fromRos(Map<String, dynamic>.from(secret), active[secret['name']?.toString()]))
        .toList()..sort((a, b) => a.name.compareTo(b.name));
      profiles = (results[2] as List).whereType<Map>()
        .map((profile) => profile['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty).toList();
    } on RosException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'تعذر قراءة المشتركين من الراوتر. تحقق من الاتصال وصلاحيات REST.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<Subscriber> get visible {
    final q = query.trim().toLowerCase();
    return all.where((s) {
      if (q.isNotEmpty && !s.name.toLowerCase().contains(q) &&
          !(s.phone ?? '').toLowerCase().contains(q)) return false;
      switch (filter) {
        case SubFilter.all: return true;
        case SubFilter.online: return s.online;
        case SubFilter.offline: return !s.online;
        case SubFilter.expired: return s.expired;
        case SubFilter.expiringSoon: return !s.expired && s.daysLeft != null && s.daysLeft! <= 3;
        case SubFilter.disabled: return s.disabled;
      }
    }).toList();
  }

  void setQuery(String value) { query = value; notifyListeners(); }
  void setFilter(SubFilter value) { filter = value; notifyListeners(); }

  Future<void> add({
    required String name, required String password, required String profile,
    String? phone, int? price, int months = 1,
  }) async {
    final client = _requireClient();
    if (name.trim().isEmpty || password.isEmpty || profile.trim().isEmpty) {
      throw RosException(RosErrorType.unknown, 'أدخل اسم المستخدم وكلمة السر والبروفايل.');
    }
    final expiry = DateTime.now().add(Duration(days: 30 * months));
    await client.put('/ppp/secret', {
      'name': name.trim(), 'password': password, 'profile': profile,
      'service': 'pppoe',
      'comment': Subscriber.buildComment(expiry: expiry, phone: phone, price: price),
    });
    await load();
  }

  Future<void> setDisabled(Subscriber s, bool disabled) async {
    await _requireClient().patch('/ppp/secret/' + Uri.encodeComponent(s.id),
      {'disabled': disabled ? 'true' : 'false'});
    if (disabled && s.activeId != null) await kick(s, reload: false);
    await load();
  }

  Future<void> kick(Subscriber s, {bool reload = true}) async {
    if (s.activeId != null) {
      await _requireClient().delete('/ppp/active/' + Uri.encodeComponent(s.activeId!));
    }
    if (reload) await load();
  }

  Future<void> extend(Subscriber s, {int months = 1}) async {
    final base = s.expiry != null && s.expiry!.isAfter(DateTime.now()) ? s.expiry! : DateTime.now();
    final expiry = base.add(Duration(days: 30 * months));
    await _requireClient().patch('/ppp/secret/' + Uri.encodeComponent(s.id), {
      'disabled': 'false',
      'comment': Subscriber.buildComment(expiry: expiry, phone: s.phone, price: s.price),
    });
    await load();
  }

  Future<void> remove(Subscriber s) async {
    final client = _requireClient();
    if (s.activeId != null) await client.delete('/ppp/active/' + Uri.encodeComponent(s.activeId!));
    await client.delete('/ppp/secret/' + Uri.encodeComponent(s.id));
    await load();
  }

  Future<void> changeProfile(Subscriber s, String profile) async {
    await _requireClient().patch('/ppp/secret/' + Uri.encodeComponent(s.id), {'profile': profile});
    if (s.activeId != null) await kick(s, reload: false);
    await load();
  }

  RouterOsClient _requireClient() {
    final client = _client;
    if (client == null) throw RosException(RosErrorType.network, 'اتصل بالراوتر أولاً.');
    return client;
  }

  int get onlineCount => all.where((s) => s.online).length;
  int get expiredCount => all.where((s) => s.expired).length;
  int get expectedRevenue => all.fold(0, (sum, s) => sum + (s.price ?? 0));
}
