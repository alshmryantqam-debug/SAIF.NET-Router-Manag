import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../widgets/particle_matrix_bg.dart';

const _cyan = Color(0xFF00E5FF);
const _pink = Color(0xFFFF4081);
const _panel = Color(0x99101829);

class HologramDashboardScreen extends ConsumerStatefulWidget {
  const HologramDashboardScreen({super.key});

  @override
  ConsumerState<HologramDashboardScreen> createState() =>
      _HologramDashboardScreenState();
}

class _HologramDashboardScreenState
    extends ConsumerState<HologramDashboardScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (ref.read(connectionProvider).isConnected) {
        ref.invalidate(systemResourceProvider);
        ref.invalidate(identityProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);
    final resource = ref.watch(systemResourceProvider);
    final identity = ref.watch(identityProvider);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: _cyan.withOpacity(0.09),
                              border: Border.all(color: _cyan.withOpacity(0.55)),
                              boxShadow: [
                                BoxShadow(
                                  color: _cyan.withOpacity(0.16),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.memory, color: _cyan),
                          ),
                          const SizedBox(width: 13),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SAIF.NET',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'HOLOGRAPHIC COMMAND CENTER',
                                  style: TextStyle(
                                    color: _cyan,
                                    fontSize: 9,
                                    letterSpacing: 1.6,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(connected: connection.isConnected),
                        ],
                      ),
                      const SizedBox(height: 27),
                      const Text(
                        'NETWORK OVERVIEW',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Live system telemetry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        connection.isConnected
                            ? 'Connected router • refreshing every 5 seconds'
                            : 'Connect to a MikroTik router to view live telemetry',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _HologramPanel(
                    height: size.height * 0.47,
                    child: resource.when(
                      loading: () => const _LoadingState(),
                      error: (error, stack) => _OfflineState(
                        connected: connection.isConnected,
                        message: connection.error ?? 'Router telemetry unavailable',
                      ),
                      data: (data) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.radar, color: _cyan, size: 20),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Text(
                                  'CORE SYSTEM TELEMETRY',
                                  style: TextStyle(
                                    color: _cyan,
                                    fontSize: 10,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const _LiveDot(),
                            ],
                          ),
                          const SizedBox(height: 24),
                          identity.when(
                            data: (value) => _TelemetryRow(
                              title: 'ROUTER IDENTITY',
                              value: value.isNotEmpty
                                  ? value
                                  : (data.boardName.isNotEmpty
                                      ? data.boardName
                                      : 'MikroTik Router'),
                              icon: Icons.memory,
                            ),
                            loading: () => _TelemetryRow(
                              title: 'ROUTER IDENTITY',
                              value: data.boardName.isEmpty
                                  ? 'Loading…'
                                  : data.boardName,
                              icon: Icons.memory,
                            ),
                            error: (_, __) => _TelemetryRow(
                              title: 'ROUTER IDENTITY',
                              value: data.boardName.isEmpty
                                  ? 'Unavailable'
                                  : data.boardName,
                              icon: Icons.memory,
                            ),
                          ),
                          const SizedBox(height: 19),
                          _TelemetryRow(
                            title: 'SYSTEM UPTIME',
                            value: data.uptime.isEmpty ? '—' : data.uptime,
                            icon: Icons.schedule,
                          ),
                          const SizedBox(height: 19),
                          _TelemetryRow(
                            title: 'ROUTEROS VERSION',
                            value: data.version.isEmpty ? '—' : data.version,
                            icon: Icons.verified_outlined,
                          ),
                          const Spacer(),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricGauge(
                                  title: 'CPU LOAD',
                                  value: data.cpuLoad.clamp(0, 100).toDouble(),
                                  valueText: '${data.cpuLoad}%',
                                  color: _pink,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _MetricGauge(
                                  title: 'MEMORY USED',
                                  value: data.memUsedPercent,
                                  valueText: '${data.memUsedPercent.round()}%',
                                  color: _cyan,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniTelemetryCard(
                          icon: Icons.memory,
                          label: 'CPU CORES',
                          value: resource.when(
                            data: (d) => d.cpuCount.toString(),
                            loading: () => '—',
                            error: (_, __) => '—',
                          ),
                          accent: _pink,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _MiniTelemetryCard(
                          icon: Icons.sd_storage_outlined,
                          label: 'FREE MEMORY',
                          value: resource.when(
                            data: (d) => '${d.freeMemory} MB',
                            loading: () => '—',
                            error: (_, __) => '—',
                          ),
                          accent: _cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HologramPanel extends StatelessWidget {
  const _HologramPanel({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(0.035),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: height.clamp(390, 560).toDouble(),
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: _cyan.withOpacity(0.38), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: _cyan.withOpacity(0.10),
                  blurRadius: 32,
                  spreadRadius: -8,
                ),
                BoxShadow(
                  color: _pink.withOpacity(0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -21,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: _cyan.withOpacity(0.7),
                      boxShadow: [
                        BoxShadow(color: _cyan.withOpacity(0.8), blurRadius: 12),
                      ],
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _cyan.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cyan.withOpacity(0.2)),
          ),
          child: Icon(icon, color: _cyan, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricGauge extends StatelessWidget {
  const _MetricGauge({
    required this.title,
    required this.value,
    required this.valueText,
    required this.color,
  });

  final String title;
  final double value;
  final String valueText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 10,
            letterSpacing: 1.3,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          valueText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _MiniTelemetryCard extends StatelessWidget {
  const _MiniTelemetryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(height: 13),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF55F7B2) : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: Color(0xFF55F7B2), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        const Text(
          'LIVE',
          style: TextStyle(
            color: Color(0xFF55F7B2),
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _cyan, strokeWidth: 2),
          SizedBox(height: 18),
          Text(
            'SYNCING CORE TELEMETRY',
            style: TextStyle(color: _cyan, fontSize: 10, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({required this.connected, required this.message});

  final bool connected;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.warning_amber_rounded : Icons.router_outlined,
            color: _pink,
            size: 44,
          ),
          const SizedBox(height: 15),
          Text(
            connected ? 'TELEMETRY INTERRUPTED' : 'NO ROUTER SESSION',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected ? message : 'Open router connections and connect first.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
