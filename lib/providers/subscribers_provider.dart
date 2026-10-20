import 'package:flutter/foundation.dart';

import '../core/api/router_client.dart';
import '../core/api/routeros_client.dart' show RosException, RosErrorType;
import '../core/billing/expiry_guard.dart';
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
  final Set<String> scheduledNames = <String>{};
  bool _sweeping = false;

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
      // PPP secrets are the primary data source. Optional endpoints must not
      // prevent the subscriber list from appearing if one of them is denied.
      final dynamic secretsResponse = await client.get('ppp/secret');
      final List secrets;
      if (secretsResponse is List) {
        secrets = secretsResponse;
      } else if (secretsResponse is Map) {
        secrets = [secretsResponse];
      } else {
        throw const FormatException('استجابة قائمة PPPoE غير متوقعة من الراوتر.');
      }

      final warnings = <String>[];
      scheduledNames.clear();
      try {
        final dynamic schedulerResponse = await client.get('system/scheduler');
        final List schedulerRows = schedulerResponse is List ? schedulerResponse : schedulerResponse is Map ? [schedulerResponse] : const [];
        for (final item in schedulerRows) {
          if (item is Map && item['name'] != null) {
            final n = item['name'].toString();
            if (n.startsWith('nova-exp-')) scheduledNames.add(n.substring('nova-exp-'.length));
          }
        }
      } catch (e) { warnings.add('تعذر قراءة جدولة انتهاء الاشتراكات: $e'); }
      final active = <String, Map>{};
      try {
        final dynamic activeResponse = await client.get('ppp/active');
        final List activeRows = activeResponse is List
            ? activeResponse
            : activeResponse is Map
                ? [activeResponse]
                : const [];
        for (final item in activeRows) {
          if (item is Map && item['name'] != null) {
            active[item['name'].toString()] = item;
          }
        }
      } catch (e) {
        warnings.add('تعذر جلب حالة الاتصال الحالية: $e');
      }

      all = secrets.whereType<Map>().map((secret) {
        final normalized = Map<String, dynamic>.from(secret);
        final name = normalized['name']?.toString();
        normalized['_expiryScheduled'] = name != null && scheduledNames.contains(name);
        return Subscriber.fromRos(normalized, name == null ? null : active[name]);
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      try {
        final dynamic profileResponse = await client.get('ppp/profile');
        final List profileRows = profileResponse is List
            ? profileResponse
            : profileResponse is Map
                ? [profileResponse]
                : const [];
        profiles = profileRows.whereType<Map>()
            .map((profile) => profile['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      } catch (e) {
        profiles = [];
        warnings.add('تعذر جلب بروفايلات PPPoE: $e');
      }
      error = warnings.isEmpty ? null : warnings.join('\n');
      await sweep();
    } on RosException catch (e) {
      error = 'فشل جلب قائمة PPPoE: ${e.message}';
    } catch (e) {
      error = 'فشل قراءة قائمة PPPoE: $e';
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
    await ExpiryGuard.schedule(client, name.trim(), expiry);
    await load();
  }

  Future<void> setDisabled(Subscriber s, bool disabled) async {
    await _requireClient().patch('/ppp/secret/' + Uri.encodeComponent(s.id),
      {'disabled': disabled ? 'true' : 'false'});
    if (disabled && s.activeId != null) await kick(s, reload: false);
    // Manual disabling intentionally leaves the router expiry scheduler intact.
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
    final client = _requireClient();
    await client.patch('/ppp/secret/' + Uri.encodeComponent(s.id), {
      'disabled': 'false',
      'comment': Subscriber.buildComment(expiry: expiry, phone: s.phone, price: s.price),
    });
    await ExpiryGuard.schedule(client, s.name, expiry);
    await load();
  }

  Future<void> remove(Subscriber s) async {
    final client = _requireClient();
    if (s.activeId != null) await client.delete('/ppp/active/' + Uri.encodeComponent(s.activeId!));
    await client.delete('/ppp/secret/' + Uri.encodeComponent(s.id));
    await ExpiryGuard.cancel(client, s.name);
    await load();
  }

  Future<void> changeProfile(Subscriber s, String profile) async {
    await _requireClient().patch('/ppp/secret/' + Uri.encodeComponent(s.id), {'profile': profile});
    if (s.activeId != null) await kick(s, reload: false);
    await load();
  }

  Future<void> sweep() async {
    final client = _client;
    if (client == null || _sweeping) return;
    _sweeping = true;
    var changed = false;
    try {
      for (final s in List<Subscriber>.from(all)) {
        if (!s.expired || s.disabled) continue;
        try {
          await client.patch('/ppp/secret/' + Uri.encodeComponent(s.id), {'disabled': 'true'});
          if (s.activeId != null) {
            try { await client.delete('/ppp/active/' + Uri.encodeComponent(s.activeId!)); } catch (_) {}
          }
          final i = all.indexWhere((item) => item.id == s.id);
          if (i >= 0) all[i] = s.copyWith(disabled: true, online: false, clearActiveId: true);
          changed = true;
        } catch (e) {
          error = [if (error != null && error!.isNotEmpty) error!, 'تعذر تعطيل الاشتراك المنتهي ${s.name}: $e'].join('\n');
        }
      }
    } finally {
      _sweeping = false;
      if (changed || error != null) notifyListeners();
    }
  }

  Future<int> syncExpirySchedules() async {
    final client = _requireClient();
    var count = 0;
    final now = DateTime.now();
    for (final s in List<Subscriber>.from(all)) {
      final expiry = s.expiry;
      if (expiry == null || !expiry.isAfter(now)) continue;
      await ExpiryGuard.schedule(client, s.name, expiry);
      scheduledNames.add(s.name);
      final i = all.indexWhere((item) => item.id == s.id);
      if (i >= 0) all[i] = s.copyWith(expiryScheduled: true);
      count++;
    }
    notifyListeners();
    return count;
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
