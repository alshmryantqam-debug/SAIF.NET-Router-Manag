import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hotspot_user.dart';
import '../models/pppoe_user.dart';
import '../models/router_config.dart';
import '../services/mikrotik_service.dart';
import '../services/routeros_rest_api.dart';
import '../services/storage_service.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier();
});

final mikrotikProvider = Provider<MikrotikService>((ref) {
  return MikrotikService();
});

final storageProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class ConnectionState {
  const ConnectionState({
    this.isConnected = false,
    this.isBusy = false,
    this.error,
    this.result,
    this.activeProfile,
  });

  final bool isConnected;
  final bool isBusy;
  final String? error;
  final ConnectionResult? result;
  final RouterProfile? activeProfile;

  ConnectionState copyWith({
    bool? isConnected,
    bool? isBusy,
    String? error,
    ConnectionResult? result,
    RouterProfile? activeProfile,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return ConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
      activeProfile: activeProfile ?? this.activeProfile,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  ConnectionNotifier(this._ref) : super(const ConnectionState()) {
    _restoreLastSession();
  }

  final Ref _ref;

  MikrotikService get _service => _ref.read(mikrotikProvider);
  StorageService get _storage => _ref.read(storageProvider);
  RouterRefreshNotifier get _refresh => _ref.read(routerRefreshProvider);

  Future<void> _restoreLastSession() async {
    final last = await _storage.getLastUsed();
    if (last != null) {
      state = state.copyWith(activeProfile: last);
    }
  }

  Future<bool> connect(RouterProfile profile) async {
    state = state.copyWith(
      isBusy: true,
      clearError: true,
      clearResult: true,
    );

    try {
      final result = await _service.connect(profile);

      await _storage.addOrUpdate(profile);
      await _storage.setActive(profile.id);
      await _storage.setLastUsed(profile.id);

      state = ConnectionState(
        isConnected: true,
        isBusy: false,
        result: result,
        activeProfile: profile,
      );

      _refresh.notify();
      return true;
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        isBusy: false,
        error: _cleanError(e),
      );
      _refresh.notify();
      return false;
    }
  }

  Future<ConnectionResult?> testConnection(RouterProfile profile) async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final result = await _service.connect(profile);
      state = state.copyWith(
        isBusy: false,
        result: result,
        activeProfile: profile,
      );
      await _service.disconnect();
      state = state.copyWith(isConnected: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: _cleanError(e),
      );
      return null;
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    await _storage.clearActive();
    state = const ConnectionState();
    _refresh.notify();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _cleanError(Object e) {
    final s = e.toString();
    return s
        .replaceAll('Exception: ', '')
        .replaceAll('RouterOsException: ', '');
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>(
  (ref) => ConnectionNotifier(ref),
);

final connectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isConnected;
});

final systemResourceProvider =
    FutureProvider.autoDispose<SystemResource>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) {
    throw const RouterOsException('غير متصل بالراوتر',
        kind: RouterOsErrorKind.network);
  }
  return service.systemResource();
});

final identityProvider = FutureProvider.autoDispose<String>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return '';
  return service.systemIdentity();
});

final hotspotUsersProvider =
    FutureProvider.autoDispose<List<HotspotUser>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.hotspotUsers();
});

final hotspotActiveProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.hotspotActive();
});

final hotspotProfilesProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.hotspotProfiles();
});

final pppoeUsersProvider =
    FutureProvider.autoDispose<List<PppoeUser>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.pppoeSecrets();
});

final pppoeActiveProvider =
    FutureProvider.autoDispose<List<PppoeActive>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.pppoeActive();
});

final interfacesProvider = FutureProvider.autoDispose<List<InterfaceInfo>>(
  (ref) async {
    final service = ref.watch(mikrotikProvider);
    if (!service.isConnected) return [];
    return service.interfaces();
  },
);

final ipAddressesProvider =
    FutureProvider.autoDispose<List<IpAddressInfo>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.ipAddresses();
});

final dhcpLeasesProvider =
    FutureProvider.autoDispose<List<DhcpLease>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.dhcpLeases();
});

final firewallRulesProvider =
    FutureProvider.autoDispose<List<FirewallRule>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.firewallRules();
});

final savedRoutersProvider =
    FutureProvider.autoDispose<List<RouterProfile>>((ref) async {
  return ref.watch(storageProvider).loadAll();
});
/// Read-only RouterOS service table used by the dashboard security audit.
final routerServicesProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final service = ref.watch(mikrotikProvider);
  if (!service.isConnected) return [];
  return service.runCommand('/ip/service');
});
