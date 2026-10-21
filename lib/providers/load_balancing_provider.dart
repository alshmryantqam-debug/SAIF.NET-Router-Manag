import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pcc_configuration.dart';
import '../services/mikrotik_service.dart';
import 'connection_provider.dart';

class LoadBalancingState {
  const LoadBalancingState({
    this.lanInterface = 'bridge-local',
    this.wans = const <PccWanConfig>[],
    this.isApplying = false,
    this.error,
    this.message,
    this.statusMessage,
  });

  final String lanInterface;
  final List<PccWanConfig> wans;
  final bool isApplying;
  final String? error;
  final String? message;
  final String? statusMessage;

  int get totalWeight =>
      wans.fold<int>(0, (sum, wan) => sum + wan.weight.round());

  LoadBalancingState copyWith({
    String? lanInterface,
    List<PccWanConfig>? wans,
    bool? isApplying,
    String? error,
    String? message,
    String? statusMessage,
    bool clearError = false,
    bool clearMessage = false,
    bool clearStatusMessage = false,
  }) {
    return LoadBalancingState(
      lanInterface: lanInterface ?? this.lanInterface,
      wans: wans ?? this.wans,
      isApplying: isApplying ?? this.isApplying,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
      statusMessage: clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }
}

class LoadBalancingNotifier extends StateNotifier<LoadBalancingState> {
  LoadBalancingNotifier(this._ref) : super(const LoadBalancingState());

  final Ref _ref;

  void setLanInterface(String value) {
    state = state.copyWith(
      lanInterface: value,
      clearError: true,
      clearMessage: true,
    );
  }

  void setWans(List<PccWanConfig> wans) {
    state = state.copyWith(
      wans: List<PccWanConfig>.unmodifiable(wans),
      clearError: true,
      clearMessage: true,
    );
  }

  void addWan(String interfaceName) {
    if (state.wans.length >= 4 ||
        interfaceName.trim().isEmpty ||
        interfaceName == state.lanInterface ||
        state.wans.any((wan) => wan.interfaceName == interfaceName)) {
      return;
    }
    state = state.copyWith(
      wans: List<PccWanConfig>.unmodifiable([
        ...state.wans,
        PccWanConfig(interfaceName: interfaceName, gateway: '', weight: 1),
      ]),
      clearError: true,
      clearMessage: true,
    );
  }

  void removeWan(int index) {
    if (state.wans.length <= 2) {
      state = state.copyWith(
        error: 'يلزم وجود خطّي WAN على الأقل لتكوين PCC.',
        clearMessage: true,
      );
      return;
    }
    if (index < 0 || index >= state.wans.length) return;
    final updated = List<PccWanConfig>.of(state.wans)..removeAt(index);
    state = state.copyWith(
      wans: List<PccWanConfig>.unmodifiable(updated),
      clearError: true,
      clearMessage: true,
    );
  }

  void updateWan(
    int index, {
    String? interfaceName,
    String? gateway,
    double? weight,
  }) {
    if (index < 0 || index >= state.wans.length) return;
    final old = state.wans[index];
    if (interfaceName != null &&
        state.wans.asMap().entries.any(
          (entry) =>
              entry.key != index &&
              entry.value.interfaceName == interfaceName,
        )) {
      state = state.copyWith(
        error: 'لا يمكن استخدام واجهة WAN نفسها لأكثر من خط.',
        clearMessage: true,
      );
      return;
    }
    final updated = List<PccWanConfig>.of(state.wans);
    updated[index] = old.copyWith(
      interfaceName: interfaceName,
      gateway: interfaceName != null && interfaceName != old.interfaceName
          ? ''
          : gateway,
      weight: weight?.clamp(1.0, 10.0).roundToDouble(),
    );
    state = state.copyWith(
      wans: List<PccWanConfig>.unmodifiable(updated),
      clearError: true,
      clearMessage: true,
    );
  }

  Future<bool> apply({
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) async {
    if (state.isApplying) return false;
    final snapshot = state;
    state = state.copyWith(
      isApplying: true,
      statusMessage: 'جارٍ بدء محرك الدمج والتحقق من إعدادات الراوتر...',
      clearError: true,
      clearMessage: true,
      clearStatusMessage: true,
    );
    try {
      final message = await PccFusionEngine(_ref.read(mikrotikProvider)).execute(
            lanInterface: snapshot.lanInterface,
            wans: snapshot.wans,
            explicitlyConfirmed: explicitlyConfirmed,
            backupVerified: backupVerified,
            rollbackPlanAvailable: rollbackPlanAvailable,
            onProgress: (status) {
              state = state.copyWith(
                statusMessage: status,
                clearError: true,
                clearMessage: true,
              );
            },
          );
      state = state.copyWith(
        isApplying: false,
        message: message,
        statusMessage: 'اكتمل محرك الدمج والتحقق من الموارد.',
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isApplying: false,
        statusMessage: 'فشل التنفيذ؛ تمت محاولة التراجع عن الموارد الجديدة.',
        error: error.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

final loadBalancingProvider =
    StateNotifierProvider<LoadBalancingNotifier, LoadBalancingState>(
  (ref) => LoadBalancingNotifier(ref),
);
