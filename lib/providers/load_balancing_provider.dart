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
  });

  final String lanInterface;
  final List<PccWanConfig> wans;
  final bool isApplying;
  final String? error;
  final String? message;

  int get totalWeight =>
      wans.fold<int>(0, (sum, wan) => sum + wan.weight.round());

  LoadBalancingState copyWith({
    String? lanInterface,
    List<PccWanConfig>? wans,
    bool? isApplying,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return LoadBalancingState(
      lanInterface: lanInterface ?? this.lanInterface,
      wans: wans ?? this.wans,
      isApplying: isApplying ?? this.isApplying,
      error: clearError ? null : (error ?? this.error),
      message: clearMessage ? null : (message ?? this.message),
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
      clearError: true,
      clearMessage: true,
    );
    try {
      final message = await _ref.read(mikrotikProvider).applyPccLoadBalancing(
            lanInterface: snapshot.lanInterface,
            wans: snapshot.wans,
            explicitlyConfirmed: explicitlyConfirmed,
            backupVerified: backupVerified,
            rollbackPlanAvailable: rollbackPlanAvailable,
          );
      state = state.copyWith(isApplying: false, message: message);
      return true;
    } catch (error) {
      state = state.copyWith(
        isApplying: false,
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
