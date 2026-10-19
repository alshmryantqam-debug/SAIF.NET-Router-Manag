import 'dart:math';

import 'package:flutter/material.dart';

import '../models/hotspot_user.dart';
import 'connection_provider.dart';

class HotspotProvider with ChangeNotifier {
  final ConnectionProvider _connectionProvider;
  List<HotspotUser> _users = [];
  bool _isLoading = false;

  HotspotProvider(this._connectionProvider);

  List<HotspotUser> get users => List.unmodifiable(_users);
  bool get isLoading => _isLoading;

  Future<void> fetchUsers() async {
    final dio = _connectionProvider.dio;
    if (dio == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await dio.get('/ip/hotspot/user');
      if (response.statusCode == 200 && response.data is List) {
        _users = (response.data as List)
            .map((e) => HotspotUser.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching Hotspot users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleUserStatus(String id, bool currentState) async {
    final dio = _connectionProvider.dio;
    if (dio == null) return false;

    try {
      final encodedId = Uri.encodeComponent(id);
      await dio.patch('/ip/hotspot/user/$encodedId', data: {
        'disabled': (!currentState).toString(),
      });
      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Error changing Hotspot user status: $e');
      return false;
    }
  }

  // توليد بطاقات دخول عشوائية.
  Future<bool> generateVouchers(
    int count,
    String profile,
    String serverLength,
  ) async {
    final dio = _connectionProvider.dio;
    if (dio == null || count < 1 || count > 500) return false;

    final length = int.tryParse(serverLength);
    if (length == null || length < 4 || length > 16) return false;

    _isLoading = true;
    notifyListeners();

    try {
      const chars = '1234567890';
      final rnd = Random.secure();

      for (int i = 0; i < count; i++) {
        final randomCode = String.fromCharCodes(
          Iterable.generate(
            length,
            (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
          ),
        );

        await dio.put('/ip/hotspot/user', data: {
          'server': 'all',
          'name': randomCode,
          'password': randomCode,
          'profile': profile,
          'comment': 'Nova-Generated',
        });
      }

      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Error generating Hotspot vouchers: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
