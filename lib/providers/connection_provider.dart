import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mikrotik_service.dart';

/// Singleton instance of MikrotikService (preserves connection state)
final mikrotikProvider = Provider<MikrotikService>((ref) {
  return MikrotikService();
});

/// Current connection status
final connectedProvider = StateProvider<bool>((ref) => false);

/// System resource (auto-disposed)
final resourceProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) {
    throw Exception('غير متصل بالراوتر');
  }
  return service.resource();
});

/// Identity (auto-disposed)
final identityProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) {
    throw Exception('غير متصل بالراوتر');
  }
  return service.identity();
});

/// Hotspot users (auto-disposed)
final hotspotUsersProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return <dynamic>[];
  return service.hotspotUsers();
});

/// PPPoE users (auto-disposed)
final pppUsersProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return <dynamic>[];
  return service.pppUsers();
});
