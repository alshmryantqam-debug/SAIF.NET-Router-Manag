import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/api/router_client.dart';
import '../core/api/routeros_client.dart' show RosException, RosErrorType;
import '../models/hotspot_user.dart';

class HotspotProvider extends ChangeNotifier {
  RouterOsClient? _client;
  List<HotspotUser> _users = [];
  bool _isLoading = false;
  int _activeCount = 0;
  String? _error;

  List<HotspotUser> get users => List.unmodifiable(_users);
  bool get isLoading => _isLoading;
  int get activeCount => _activeCount;
  String? get error => _error;

  void attach(RouterOsClient? client) {
    if (identical(client, _client)) return;
    _client = client;
    _users = [];
    _activeCount = 0;
    _error = null;
    if (client == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final client = _client;
    if (client == null) {
      _error = 'اتصل بالراوتر أولاً.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await client.getHotspotUsers();
      _users = data
          .whereType<Map>()
          .map((item) => HotspotUser.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      try {
        final dynamic active = await client.get('ip/hotspot/active');
        if (active is List) {
          _activeCount = active.length;
        } else if (active is Map) {
          _activeCount = active.isEmpty ? 0 : 1;
        } else {
          _activeCount = 0;
        }
      } catch (_) {
        // Accounts remain editable when the active-session permission is denied.
      }
    } on RosException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'فشل جلب مستخدمي الهوتسبوت: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleUserStatus(String id, bool currentState) async {
    final client = _client;
    if (client == null) {
      _error = 'اتصل بالراوتر أولاً.';
      notifyListeners();
      return false;
    }
    try {
      await client.toggleHotspotUser(id, !currentState);
      await fetchUsers();
      return _error == null;
    } on RosException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'تعذر تغيير حالة البطاقة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser({
    required String id,
    required String name,
    required String profile,
    String? password,
  }) async {
    final client = _client;
    if (client == null) {
      _error = 'اتصل بالراوتر أولاً.';
      notifyListeners();
      return false;
    }
    if (name.trim().isEmpty || profile.trim().isEmpty) {
      _error = 'اسم البطاقة والبروفايل مطلوبان.';
      notifyListeners();
      return false;
    }

    try {
      final values = <String, dynamic>{
        'name': name.trim(),
        'profile': profile.trim(),
      };
      if (password != null && password.isNotEmpty) {
        values['password'] = password;
      }
      await client.patch(
        '/ip/hotspot/user/${Uri.encodeComponent(id)}',
        values,
      );
      await fetchUsers();
      return _error == null;
    } on RosException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'تعذر تعديل البطاقة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String id) async {
    final client = _client;
    if (client == null) {
      _error = 'اتصل بالراوتر أولاً.';
      notifyListeners();
      return false;
    }
    try {
      await client.removeHotspotUser(id);
      await fetchUsers();
      return _error == null;
    } on RosException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'تعذر حذف البطاقة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> generateVouchers(int count, String profile, String serverLength) async {
    final client = _client;
    final length = int.tryParse(serverLength);
    if (client == null ||
        count < 1 ||
        count > 500 ||
        length == null ||
        length < 4 ||
        length > 16 ||
        profile.trim().isEmpty) {
      _error = client == null
          ? 'اتصل بالراوتر أولاً.'
          : 'تحقق من العدد وطول الكود والبروفايل.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      const chars = '1234567890';
      final random = Random.secure();
      for (var i = 0; i < count; i++) {
        final code = String.fromCharCodes(
          Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
        );
        await client.createHotspotUser(
          name: code,
          password: code,
          profile: profile.trim(),
          server: 'all',
          comment: 'NOVA-Generated',
        );
      }
      await fetchUsers();
      return _error == null;
    } on RosException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'تعذر توليد البطاقات: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}