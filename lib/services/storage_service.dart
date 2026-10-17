import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/router_config.dart';

class StorageService {
  StorageService._internal();

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _keyRouters = 'tikplus.routers';
  static const String _keyActiveId = 'tikplus.active_router_id';
  static const String _keyLastUsed = 'tikplus.last_used_router_id';

  Future<List<RouterProfile>> loadAll() async {
    try {
      final raw = await _storage.read(key: _keyRouters);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => RouterProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<RouterProfile> routers) async {
    final data = routers.map((r) => r.toJson()).toList();
    await _storage.write(key: _keyRouters, value: jsonEncode(data));
  }

  Future<void> addOrUpdate(RouterProfile profile) async {
    final list = await loadAll();
    final idx = list.indexWhere((r) => r.id == profile.id);
    if (idx >= 0) {
      list[idx] = profile;
    } else {
      list.add(profile);
    }
    await saveAll(list);
  }

  Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((r) => r.id == id);
    await saveAll(list);

    final activeId = await getActiveId();
    if (activeId == id) {
      await clearActive();
    }
    final lastUsed = await getLastUsedId();
    if (lastUsed == id) {
      await _storage.delete(key: _keyLastUsed);
    }
  }

  Future<RouterProfile?> findById(String id) async {
    final list = await loadAll();
    try {
      return list.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _keyRouters);
    await _storage.delete(key: _keyActiveId);
    await _storage.delete(key: _keyLastUsed);
  }

  Future<void> setActive(String id) async {
    await _storage.write(key: _keyActiveId, value: id);
  }

  Future<String?> getActiveId() async {
    return _storage.read(key: _keyActiveId);
  }

  Future<RouterProfile?> getActive() async {
    final id = await getActiveId();
    if (id == null) return null;
    return findById(id);
  }

  Future<void> clearActive() async {
    await _storage.delete(key: _keyActiveId);
  }

  Future<void> setLastUsed(String id) async {
    await _storage.write(key: _keyLastUsed, value: id);
  }

  Future<String?> getLastUsedId() async {
    return _storage.read(key: _keyLastUsed);
  }

  Future<RouterProfile?> getLastUsed() async {
    final id = await getLastUsedId();
    if (id == null) return null;
    return findById(id);
  }
}