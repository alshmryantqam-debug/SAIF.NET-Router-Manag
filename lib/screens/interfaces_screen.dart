import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/routeros_client.dart' show RosException;
import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../providers/traffic_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/nova_widgets.dart';

class InterfacesScreen extends StatefulWidget {
  const InterfacesScreen({super.key});

  @override
  State<InterfacesScreen> createState() => _InterfacesScreenState();
}

class _InterfacesScreenState extends State<InterfacesScreen> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'all';
  bool _loading = false;
  bool _wanFromRouter = false;
  Set<String> _wanNames = <String>{};
  final Set<String> _pending = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final connection = context.read<ConnectionProvider>();
    final traffic = context.read<TrafficProvider>();
    await Future.wait<void>([
      connection.fetchInterfaces(),
      traffic.refreshInterfaces(),
    ]);
    final client = connection.client;
    var explicitWan = <String>{};
    if (client != null) {
      try {
        final dynamic response = await client.get('interface/list/member');
        final List members = response is List
            ? response
            : response is Map
                ? [response]
                : const [];
        explicitWan = members.whereType<Map>()
            .where((row) => (row['list'] ?? '').toString().toLowerCase() == 'wan')
            .map((row) => (row['interface'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toSet();
      } catch (_) {
        // Some RouterOS accounts may lack access to interface-list membership.
      }
    }
    final candidates = connection.interfaces.whereType<Map>()
        .where((row) {
          final type = (row['type'] ?? '').toString().toLowerCase();
          return type == 'ether' || type == 'sfp-sfpplus';
        })
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (!mounted) return;
    setState(() {
      _wanFromRouter = explicitWan.isNotEmpty;
      _wanNames = explicitWan.isNotEmpty ? explicitWan : candidates;
      _loading = false;
    });
  }

  bool _flag(dynamic value) => value == true || value?.toString() == 'true';

  List<Map<String, dynamic>> _visible(List<dynamic> items) {
    final query = _search.text.trim().toLowerCase();
    return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) {
      final name = (e['name'] ?? '').toString();
      final type = (e['type'] ?? '').toString();
      final disabled = _flag(e['disabled']);
      final running = _flag(e['running']);
      if (query.isNotEmpty && !name.toLowerCase().contains(query) && !type.toLowerCase().contains(query)) return false;
      switch (_filter) {
        case 'up': return running && !disabled;
        case 'down': return !running || disabled;
        case 'watched': return context.read<TrafficProvider>().watched.contains(name);
        case 'wan': return _wanNames.contains(name);
        default: return true;
      }
    }).toList();
  }

  int _runningCount(List<dynamic> values) => values.whereType<Map>().where((e) => _flag(e['running']) && !_flag(e['disabled'])).length;

  String _rate(double? value) {
    final bps = value ?? 0;
    if (bps >= 1000000000) return '${(bps / 1000000000).toStringAsFixed(2)} Gbps';
    if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
    if (bps >= 1000) return '${(bps / 1000).toStringAsFixed(0)} Kbps';
    return '${bps.toStringAsFixed(0)} bps';
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? NovaColors.danger : NovaColors.surface2,
      ));
  }

  Future<void> _toggleEnabled(Map<String, dynamic> item) async {
    final connection = context.read<ConnectionProvider>();
    final client = connection.client;
    final id = (item['.id'] ?? '').toString();
    final name = (item['name'] ?? 'الواجهة').toString();
    if (!connection.isConnected || client == null) {
      _message('اتصل بالراوتر أولاً لتنفيذ التغيير.', error: true);
      return;
    }
    if (id.isEmpty) {
      _message('لم يرسل الراوتر معرّف الواجهة، لذلك لم يتم تغييرها.', error: true);
      return;
    }
    final wasDisabled = _flag(item['disabled']);
    final willDisable = !wasDisabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(willDisable ? 'تعطيل الواجهة؟' : 'تفعيل الواجهة؟'),
        content: Text(willDisable
          ? 'سيتم تعطيل $name فعلياً على الراوتر. قد يؤدي ذلك إلى قطع الاتصال إذا كانت الواجهة مستخدمة للوصول إلى الراوتر أو كانت تحمل خط إنترنت.'
          : 'سيتم تفعيل $name فعلياً على الراوتر. قد يؤثر ذلك على حركة الشبكة المرتبطة بها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
          FilledButton(
            style: willDisable ? FilledButton.styleFrom(backgroundColor: NovaColors.danger) : null,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(willDisable ? 'تعطيل الواجهة' : 'تفعيل الواجهة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _pending.add(id));
    try {
      await client.patch('interface/${Uri.encodeComponent(id)}', {'disabled': willDisable ? 'true' : 'false'});
      await _load();
      _message(willDisable ? 'تم تعطيل $name على الراوتر.' : 'تم تفعيل $name على الراوتر.');
    } on RosException catch (e) {
      _message('رفض الراوتر العملية: ${e.message}', error: true);
    } catch (e) {
      _message('تعذر تغيير حالة $name: $e', error: true);
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  void _details(Map<String, dynamic> item, TrafficProvider traffic) {
    final name = (item['name'] ?? '—').toString();
    final type = (item['type'] ?? 'غير معروف').toString();
    final mac = (item['mac-address'] ?? 'غير متاح').toString();
    final mtu = (item['mtu'] ?? '—').toString();
    final running = _flag(item['running']);
    final disabled = _flag(item['disabled']);
    final history = traffic.history[name] ?? const <TrafficSample>[];
    final last = history.isEmpty ? null : history.last;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NovaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: NovaColors.primary.withOpacity(.16), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.settings_ethernet_rounded, color: NovaColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(type, style: const TextStyle(color: NovaColors.muted)),
              ])),
              StatusPill(disabled ? 'معطّل' : running ? 'الرابط يعمل' : 'لا يوجد رابط', disabled ? NovaColors.danger : running ? NovaColors.success : NovaColors.warn),
            ]),
            const SizedBox(height: 18),
            _detailRow('عنوان MAC', mac),
            _detailRow('MTU', mtu),
            _detailRow('حالة المنفذ', disabled ? 'تعطيل إداري' : running ? 'نشط' : 'مفعّل ولكن الرابط غير نشط'),
            _detailRow('تنزيل مباشر', _rate(last?.rx)),
            _detailRow('رفع مباشر', _rate(last?.tx)),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: () {
              Navigator.pop(sheet);
              traffic.toggleWatch(name);
              _message(traffic.watched.contains(name) ? 'بدأت مراقبة $name' : 'أوقفت مراقبة $name');
            }, icon: Icon(traffic.watched.contains(name) ? Icons.visibility_off_outlined : Icons.monitor_heart_outlined),
              label: Text(traffic.watched.contains(name) ? 'إزالة من المراقبة الحية' : 'مراقبة الحركة الحية')),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: () { Navigator.pop(sheet); _toggleEnabled(item); },
              icon: Icon(disabled ? Icons.power_rounded : Icons.power_off_rounded),
              label: Text(disabled ? 'تفعيل الواجهة' : 'تعطيل الواجهة')),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: NovaColors.muted))),
      const SizedBox(width: 14),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _filterChip(String value, String label) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: NovaColors.primary.withOpacity(.22),
      side: BorderSide(color: _filter == value ? NovaColors.primary : NovaColors.border),
    ),
  );

  Widget _interfaceCard(Map<String, dynamic> item, TrafficProvider traffic, ConnectionProvider connection) {
    final name = (item['name'] ?? 'واجهة').toString();
    final type = (item['type'] ?? 'interface').toString();
    final disabled = _flag(item['disabled']);
    final running = _flag(item['running']);
    final monitored = traffic.watched.contains(name);
    final id = (item['.id'] ?? '').toString();
    final history = traffic.history[name] ?? const <TrafficSample>[];
    final last = history.isEmpty ? null : history.last;
    final stateColor = disabled ? NovaColors.danger : running ? NovaColors.success : NovaColors.warn;
    final stateLabel = disabled ? 'معطّل' : running ? 'يعمل' : 'بانتظار الرابط';
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassCard(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: stateColor.withOpacity(.13), borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.cable_rounded, color: stateColor, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 7, runSpacing: 4, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 7, runSpacing: 4, children: [
                Text(type, style: const TextStyle(fontSize: 12, color: NovaColors.muted)),
                if (_wanNames.contains(name)) StatusPill(_wanFromRouter ? 'WAN' : 'مرشّح WAN', _wanFromRouter ? NovaColors.primary : NovaColors.warn),
              ]),
                if (_wanNames.contains(name)) StatusPill(_wanFromRouter ? 'WAN' : 'مرشّح WAN', _wanFromRouter ? NovaColors.primary : NovaColors.warn),
              ]),
            ])),
            StatusPill(stateLabel, stateColor),
            PopupMenuButton<String>(
              tooltip: 'إجراءات الواجهة',
              onSelected: (action) {
                if (action == 'details') _details(item, traffic);
                if (action == 'watch') {
                  traffic.toggleWatch(name);
                  _message(traffic.watched.contains(name) ? 'بدأت مراقبة $name' : 'أوقفت مراقبة $name');
                }
                if (action == 'enable') _toggleEnabled(item);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'details', child: ListTile(leading: Icon(Icons.info_outline), title: Text('التفاصيل'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'watch', child: ListTile(leading: Icon(monitored ? Icons.visibility_off_outlined : Icons.monitor_heart_outlined), title: Text(monitored ? 'إيقاف المراقبة' : 'مراقبة الحركة'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'enable', child: ListTile(leading: Icon(disabled ? Icons.power : Icons.power_off), title: Text(disabled ? 'تفعيل الواجهة' : 'تعطيل الواجهة'), contentPadding: EdgeInsets.zero)),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _rateCell(Icons.south_rounded, 'تنزيل', _rate(last?.rx), const Color(0xFF65C7B0))),
            const SizedBox(width: 10),
            Expanded(child: _rateCell(Icons.north_rounded, 'رفع', _rate(last?.tx), const Color(0xFF8EA6FF))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(monitored ? 'المراقبة الحية مفعّلة' : 'المراقبة الحية متوقفة', style: TextStyle(fontSize: 12, color: monitored ? NovaColors.success : NovaColors.muted))),
            if (_pending.contains(id)) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else TextButton.icon(onPressed: connection.isConnected && id.isNotEmpty ? () => _toggleEnabled(item) : null,
              icon: Icon(disabled ? Icons.power_rounded : Icons.power_off_rounded, size: 17),
              label: Text(disabled ? 'تفعيل' : 'تعطيل')),
            IconButton(tooltip: monitored ? 'إيقاف المراقبة' : 'بدء المراقبة', onPressed: () => traffic.toggleWatch(name),
              icon: Icon(monitored ? Icons.visibility_off_outlined : Icons.monitor_heart_outlined, color: monitored ? NovaColors.primary : NovaColors.muted)),
          ]),
        ]),
      ),
    );
  }

  Widget _rateCell(IconData icon, String label, String rate, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: NovaColors.surface2.withOpacity(.65), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(rate, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final traffic = context.watch<TrafficProvider>();
    final items = _visible(connection.interfaces);
    final running = _runningCount(connection.interfaces);
    final watched = traffic.watched.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة خطوط الإنترنت'),
        actions: [
          IconButton(tooltip: 'تحديث الواجهات', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: NovaColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: NovaColors.gradient,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: NovaColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('حالة المنافذ والخطوط', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                  StatusPill(connection.isConnected ? 'الراوتر متصل' : 'غير متصل', connection.isConnected ? NovaColors.success : NovaColors.danger),
                ]),
                const SizedBox(height: 6),
                const Text('راقب حركة كل منفذ وتحكّم بتفعيله من الراوتر مباشرة.', style: TextStyle(color: NovaColors.muted, height: 1.5)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _metric('إجمالي الواجهات', '${connection.interfaces.length}', Icons.cable_rounded)),
                  Expanded(child: _metric(_wanFromRouter ? 'خطوط WAN' : 'مرشحات WAN', '${_wanNames.length}', Icons.language_rounded)),
                  Expanded(child: _metric('روابط تعمل', '$running', Icons.check_circle_outline_rounded)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            GlassCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1), child: TextField(
              controller: _search, onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'ابحث باسم الواجهة أو نوعها', prefixIcon: const Icon(Icons.search_rounded), border: InputBorder.none,
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _search.clear(); setState(() {}); })),
            )),
            const SizedBox(height: 10),
            SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, children: [
              _filterChip('all', 'الكل (${connection.interfaces.length})'),
              _filterChip('wan', 'خطوط WAN (${_wanNames.length})'),
              _filterChip('up', 'تعمل ($running)'),
              _filterChip('down', 'متوقفة'),
              _filterChip('watched', 'المراقبة الحية ($watched)'),
            ])),
            const SizedBox(height: 8),
            if (!connection.isConnected)
              const GlassCard(child: EmptyState(icon: Icons.link_off_rounded, title: 'لا يوجد اتصال بالراوتر', message: 'سجّل الدخول إلى MikroTik أولاً لإدارة المنافذ.'))
            else if (_loading && connection.interfaces.isEmpty)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (connection.errorMessage.isNotEmpty && connection.interfaces.isEmpty)
              GlassCard(child: EmptyState(icon: Icons.cloud_off_rounded, title: 'تعذّر جلب الواجهات', message: connection.errorMessage, actionLabel: 'إعادة المحاولة', onAction: _load))
            else if (items.isEmpty)
              const GlassCard(child: EmptyState(icon: Icons.search_off_rounded, title: 'لا توجد نتائج', message: 'غيّر البحث أو الفلتر ثم حاول مجدداً.'))
            else
              ...items.map((item) => _interfaceCard(item, traffic, connection)),
            const SizedBox(height: 8),
            Text(_wanFromRouter ? 'اكتُشفت خطوط WAN من قائمة الواجهات في MikroTik.' : 'لم تُعرّف قائمة WAN داخل MikroTik؛ لذلك تظهر منافذ Ethernet وSFP كمرشّحات فقط، وليست تصنيفاً مؤكداً لخطوط الإنترنت.', style: const TextStyle(color: NovaColors.muted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 6),
            const Text('تنبيه: تعطيل منفذ قد يقطع الإنترنت أو يفصل جلسة الإدارة إذا كان مسار الاتصال يمر عبره.', style: TextStyle(fontSize: 12, color: NovaColors.warn, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: NovaColors.primary, size: 20),
    const SizedBox(height: 8),
    Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 10)),
  ]);
}
