import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mikrotik_service.dart';

final mikrotikProvider = Provider<MikrotikService>((ref) {
  return MikrotikService();
});

final connectedProvider = StateProvider<bool>((ref) => false);

final resourceProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.resource();
});

final identityProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.identity();
});

final hotspotUsersProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return <dynamic>[];
  return service.hotspotUsers();
});

final pppUsersProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return <dynamic>[];
  return service.pppUsers();
});

final interfacesProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.interfaces();
});

final hotspotActiveProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.hotspotActive();
});

final pppActiveProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.pppActive();
});

final dhcpLeasesProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.dhcpLeases();
});

final simpleQueuesProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.simpleQueues();
});

final ipAddressesProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.ipAddresses();
});

final firewallFilterProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.firewallFilterRules();
});

final firewallNatProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.firewallNatRules();
});

final firewallMangleProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.firewallMangleRules();
});

final routesProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.routes();
});

final logsProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.logs();
});

final interfaceListMembersProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  return service.interfaceListMembers();
});

final wanTrafficProvider = FutureProvider.autoDispose((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) throw Exception('غير متصل بالراوتر');
  final members = await service.interfaceListMembers();
  final names = members
      .where((row) =>
          row is Map &&
          row['list']?.toString().toLowerCase() == 'wan' &&
          row['interface']?.toString().isNotEmpty == true)
      .map((row) => (row as Map)['interface'].toString())
      .toSet()
      .toList();
  if (names.isEmpty) return <dynamic>[];
  return service.monitorTraffic(names);
});
