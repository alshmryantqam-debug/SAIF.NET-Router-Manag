import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mikrotik_api_service.dart';

class MikrotikState {
  const MikrotikState({
    this.isConnected = false,
    this.isBusy = false,
    this.resources,
    this.errorMessage = '',
  });

  final bool isConnected;
  final bool isBusy;
  final Map<String, dynamic>? resources;
  final String errorMessage;

  MikrotikState copyWith({
    bool? isConnected,
    bool? isBusy,
    Map<String, dynamic>? resources,
    String? errorMessage,
    bool clearResources = false,
  }) {
    return MikrotikState(
      isConnected: isConnected ?? this.isConnected,
      isBusy: isBusy ?? this.isBusy,
      resources: clearResources ? null : (resources ?? this.resources),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class MikrotikNotifier extends StateNotifier<MikrotikState> {
  MikrotikNotifier() : super(const MikrotikState());

  MikrotikApiService? _apiService;
  int _requestGeneration = 0;

  Future<bool> connect(
    String ip,
    String port,
    String user,
    String pass, {
    bool useHttps = true,
    bool allowSelfSignedCertificate = false,
  }) async {
    final generation = ++_requestGeneration;
    state = state.copyWith(isBusy: true, errorMessage: '', clearResources: true);

    final candidate = MikrotikApiService(
      ip: ip,
      port: port,
      username: user,
      password: pass,
      useHttps: useHttps,
      allowSelfSignedCertificate: allowSelfSignedCertificate,
    );

    try {
      final resources = await candidate.getSystemResources();
      if (resources == null) {
        throw const MikrotikApiException('لم يرجع الراوتر بيانات موارد النظام.');
      }
      if (generation != _requestGeneration) {
        candidate.close();
        return false;
      }
      _apiService?.close();
      _apiService = candidate;
      state = MikrotikState(isConnected: true, resources: resources);
      return true;
    } catch (error) {
      candidate.close();
      if (generation == _requestGeneration) {
        _apiService?.close();
        _apiService = null;
        state = MikrotikState(
          errorMessage: error is MikrotikApiException
              ? error.message
              : 'فشل الاتصال: ${error.toString()}',
        );
      }
      return false;
    }
  }

  MikrotikApiService? get api => _apiService;

  Future<void> disconnect() async {
    ++_requestGeneration;
    _apiService?.close();
    _apiService = null;
    state = const MikrotikState();
  }

  @override
  void dispose() {
    _apiService?.close();
    _apiService = null;
    super.dispose();
  }
}

/// Kept separate from the legacy mikrotikProvider in connection_provider.dart.
final mikrotikApiProvider =
    StateNotifierProvider<MikrotikNotifier, MikrotikState>(
  (ref) => MikrotikNotifier(),
);
