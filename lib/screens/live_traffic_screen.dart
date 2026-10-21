import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_provider.dart';
import '../services/mikrotik_service.dart';
import '../widgets/cyber_traffic_graph.dart';
import '../widgets/nova_ui_kit.dart';
import '../widgets/particle_matrix_bg.dart';

const _cyan = Color(0xFF00E5FF);
const _magenta = Color(0xFFE040FB);
const _gold = Color(0xFFE5C158);
const _muted = Color(0xFF8B9AB5);

class LiveTrafficScreen extends ConsumerStatefulWidget {
  const LiveTrafficScreen({super.key});

  @override
  ConsumerState<LiveTrafficScreen> createState() => _LiveTrafficScreenState();
}

class _LiveTrafficScreenState extends ConsumerState<LiveTrafficScreen> {
  Timer? _timer;
  final List<double> _rxHistory = List<double>.filled(30, 0);
  final List<double> _txHistory = List<double>.filled(30, 0);
  List<InterfaceInfo> _interfaces = <InterfaceInfo>[];
  String? _selectedInterface;
  int? _previousRx;
  int? _previousTx;
  double _rxMbps = 0;
  double _txMbps = 0;
  bool _isMonitoring = false;
  bool _isLoadingInterfaces = false;
  String? _error;
  DateTime? _lastSample;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInterfaces() async {
    if (_isLoadingInterfaces) return;
    if (!ref.read(connectionProvider).isConnected) {
      if (mounted) setState(() => _error = 'اتصل بالراوتر أولاً لقراءة حركة المرور الحقيقية.');
      return;
    }
    setState(() {
      _isLoadingInterfaces = true;
      _error = null;
    });
    try {
      final rows = await ref.read(mikrotikProvider).interfaces();
      if (!mounted) return;
      setState(() {
        _interfaces = rows;
        if (_selectedInterface == null ||
            !rows.any((item) => item.name == _selectedInterface)) {
          _selectedInterface = rows.isNotEmpty ? rows.first.name : null;
        }
        _isLoadingInterfaces = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInterfaces = false;
        _error = 'تعذّرت قراءة الواجهات: $e';
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      _timer?.cancel();
      setState(() {
        _isMonitoring = false;
        _previousRx = null;
        _previousTx = null;
      });
      return;
    }
    if (!ref.read(connectionProvider).isConnected) {
      setState(() => _error = 'لا يوجد اتصال بالراوتر. افتح اتصالاً صالحاً ثم أعد المحاولة.');
      return;
    }
    if (_selectedInterface == null) await _loadInterfaces();
    if (!mounted || _selectedInterface == null) return;

    setState(() {
      _isMonitoring = true;
      _error = null;
      _previousRx = null;
      _previousTx = null;
      _lastSample = null;
    });
    await _sampleTraffic();
    if (!mounted || !_isMonitoring) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sampleTraffic());
  }

  Future<void> _sampleTraffic() async {
    if (!mounted || !_isMonitoring) return;
    try {
      final rows = await ref.read(mikrotikProvider).interfaces();
      if (!mounted || !_isMonitoring) return;
      final match = rows.where((item) => item.name == _selectedInterface);
      if (match.isEmpty) {
        setState(() => _error = 'الواجهة المحددة لم تعد متاحة.');
        return;
      }
      final iface = match.first;
      var rx = 0.0;
      var tx = 0.0;
      final now = DateTime.now();
      final previousTime = _lastSample;
      final oldRx = _previousRx;
      final oldTx = _previousTx;
      if (previousTime != null && oldRx != null && oldTx != null) {
        final seconds = now.difference(previousTime).inMilliseconds / 1000.0;
        if (seconds > 0 && iface.rxByte >= oldRx && iface.txByte >= oldTx) {
          rx = ((iface.rxByte - oldRx) * 8 / seconds) / 1000000;
          tx = ((iface.txByte - oldTx) * 8 / seconds) / 1000000;
        }
      }
      setState(() {
        _interfaces = rows;
        _previousRx = iface.rxByte;
        _previousTx = iface.txByte;
        _lastSample = now;
        _rxMbps = rx.isFinite ? rx : 0;
        _txMbps = tx.isFinite ? tx : 0;
        _pushHistory(_rxHistory, _rxMbps);
        _pushHistory(_txHistory, _txMbps);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل تحديث العداد: $e');
    }
  }

  void _pushHistory(List<double> history, double value) {
    history.removeAt(0);
    history.add(value);
  }

  void _changeInterface(String? name) {
    if (name == null || name == _selectedInterface) return;
    setState(() {
      _selectedInterface = name;
      _previousRx = null;
      _previousTx = null;
      _lastSample = null;
      _rxMbps = 0;
      _txMbps = 0;
      for (var i = 0; i < 30; i++) {
        _rxHistory[i] = 0;
        _txHistory[i] = 0;
      }
    });
  }

  double get _graphMax {
    final peak = <double>[..._rxHistory, ..._txHistory]
        .fold<double>(0, (previous, value) => math.max(previous, value));
    return math.max(10.0, peak * 1.2).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectionProvider).isConnected;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'محلل التدفق التكتيكي',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: _cyan, blurRadius: 12)],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث قائمة الواجهات',
            onPressed: _isLoadingInterfaces ? null : _loadInterfaces,
            icon: const Icon(Icons.sync_rounded, color: _cyan),
          ),
        ],
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              _statusBanner(connected),
              const SizedBox(height: 14),
              NovaTechPanel(
                accentColor: _gold,
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    const Icon(Icons.cable_rounded, color: _gold, size: 26),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('الواجهة المراقبة', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _interfaces.any((item) => item.name == _selectedInterface) ? _selectedInterface : null,
                          hint: Text(_isLoadingInterfaces ? 'جارٍ التحميل...' : 'اختر واجهة', style: const TextStyle(color: _muted, fontSize: 12)),
                          dropdownColor: const Color(0xFF111827),
                          style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 13),
                          items: _interfaces.map((item) => DropdownMenuItem<String>(
                            value: item.name,
                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: _changeInterface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _speedCard('التنزيل RX', _rxMbps, 'Mbps', _cyan, Icons.south_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _speedCard('الرفع TX', _txMbps, 'Mbps', _magenta, Icons.north_rounded)),
                ],
              ),
              const SizedBox(height: 14),
              NovaTechPanel(
                accentColor: _cyan,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monitor_heart_rounded, color: _cyan, size: 19),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('موجات نقل البيانات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                        Text('آخر 30 قراءة', style: TextStyle(color: _muted, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CyberTrafficGraph(rxData: _rxHistory, txData: _txHistory, maxValue: _graphMax),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _Legend(color: _cyan, label: 'RX تنزيل'),
                        _Legend(color: _magenta, label: 'TX رفع'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('مقياس الرسم يتكيّف تلقائياً مع أعلى سرعة مسجلة.', style: TextStyle(color: _muted, fontSize: 11)),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                NovaTechPanel(
                  accentColor: const Color(0xFFFF657A),
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF657A)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white70, height: 1.5))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              NovaCyberButton(
                text: _isMonitoring ? 'إيقاف المراقبة الحية' : 'بدء تحليل الطيف',
                icon: _isMonitoring ? Icons.stop_circle_rounded : Icons.radar_rounded,
                color: _isMonitoring ? const Color(0xFFFF657A) : const Color(0xFF4CAE7D),
                onPressed: _isLoadingInterfaces ? null : _toggleMonitoring,
              ),
              const SizedBox(height: 10),
              Text(
                _isMonitoring
                    ? 'تحديث حي كل ثانية • ' + (_selectedInterface ?? '—')
                    : connected
                        ? 'جاهز لقراءة عدادات الواجهة من الراوتر.'
                        : 'المراقبة الحقيقية تتطلب اتصالاً نشطاً بالراوتر.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBanner(bool connected) {
    final color = connected ? const Color(0xFF4CAE7D) : const Color(0xFFFF657A);
    return NovaTechPanel(
      accentColor: color,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(connected ? Icons.link_rounded : Icons.link_off_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(connected ? 'قناة الراوتر متصلة' : 'قناة الراوتر غير متصلة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)]),
          ),
        ],
      ),
    );
  }

  Widget _speedCard(String title, double value, String unit, Color color, IconData icon) {
    return NovaTechPanel(
      accentColor: color,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                const SizedBox(width: 4),
                Text(unit, style: const TextStyle(color: _muted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 3, decoration: BoxDecoration(color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 5)])),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
