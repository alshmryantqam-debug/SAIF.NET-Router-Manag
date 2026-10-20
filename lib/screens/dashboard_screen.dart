import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/nova_theme.dart';
import '../providers/connection_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/hotspot_provider.dart';
import '../providers/subscribers_provider.dart';
import '../providers/traffic_provider.dart';
import 'auth/router_login_screen.dart';
import 'hotspot_screen.dart';
import 'interfaces_screen.dart';
import 'pppoe_screen.dart';
import 'queues_screen.dart';
import 'tools_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onOpenSection;

  const DashboardScreen({super.key, this.onOpenSection});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardProvider>().startPolling();
      context.read<SubscribersProvider>().load();
      context.read<HotspotProvider>().fetchUsers();
      context.read<TrafficProvider>().refreshInterfaces();
    });
  }

  @override
  void dispose() {
    context.read<DashboardProvider>().stopPolling();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      context.read<DashboardProvider>().fetchResources(),
      context.read<SubscribersProvider>().load(),
      context.read<HotspotProvider>().fetchUsers(),
      context.read<ConnectionProvider>().fetchInterfaces(),
      context.read<TrafficProvider>().refreshInterfaces(),
    ]);
  }

  void _openSection(int index, Widget fallback) {
    final callback = widget.onOpenSection;
    if (callback != null) {
      callback(index);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => fallback),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? NovaColors.danger : NovaColors.surface2,
        behavior: SnackBarBehavior.floating,
      ));
  }

  String _temperature(String value) {
    final text = value.trim();
    if (text.isEmpty || text == 'غير متاح' || text == '—') return 'غير متاح';
    final lower = text.toLowerCase();
    if (lower.endsWith('c') || lower.endsWith('°c') || lower.endsWith('f')) {
      return text;
    }
    final number = double.tryParse(text);
    return number == null ? text : number.toStringAsFixed(0) + '°C';
  }

  String _voltage(String value) {
    final text = value.trim();
    if (text.isEmpty || text == 'غير متاح' || text == '—') return 'غير متاح';
    final lower = text.toLowerCase();
    if (lower.endsWith('v')) return text;
    final number = double.tryParse(text);
    return number == null ? text : text + ' V';
  }

  String _speed(double value) {
    if (value >= 1000000000) return (value / 1000000000).toStringAsFixed(2) + ' Gbps';
    if (value >= 1000000) return (value / 1000000).toStringAsFixed(2) + ' Mbps';
    if (value >= 1000) return (value / 1000).toStringAsFixed(1) + ' Kbps';
    return value.toStringAsFixed(0) + ' bps';
  }

  String _storage(int? bytes) {
    if (bytes == null || bytes < 0) return 'غير متاح';
    if (bytes >= 1073741824) {
      return (bytes / 1073741824).toStringAsFixed(1) + ' GB';
    }
    if (bytes >= 1048576) {
      return (bytes / 1048576).toStringAsFixed(1) + ' MB';
    }
    if (bytes >= 1024) return (bytes / 1024).toStringAsFixed(1) + ' KB';
    return bytes.toString() + ' B';
  }

  bool _isPhysical(RosInterface item) {
    final type = item.type.toLowerCase();
    final name = item.name.toLowerCase();
    return type.contains('ether') ||
        type.contains('sfp') ||
        name.startsWith('ether') ||
        name.startsWith('sfp');
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('قطع الاتصال؟'),
        content: const Text('سيتم فصل جلسة الإدارة الحالية والعودة إلى شاشة الاتصال. لن تتغير إعدادات الراوتر.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('قطع الاتصال'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    context.read<DashboardProvider>().attach(null);
    context.read<TrafficProvider>().attach(null);
    context.read<ConnectionProvider>().disconnect();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RouterLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _showRouterMenu() async {
    final connection = context.read<ConnectionProvider>();
    final dashboard = context.read<DashboardProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: NovaColors.surface,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('الراوتر الحالي',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _DetailLine(
                icon: Icons.router_outlined,
                label: 'الاسم',
                value: connection.routerIdentity.isEmpty ? 'غير معروف' : connection.routerIdentity,
              ),
              _DetailLine(
                icon: Icons.memory_outlined,
                label: 'الجهاز',
                value: dashboard.boardName,
              ),
              _DetailLine(
                icon: Icons.info_outline,
                label: 'RouterOS',
                value: dashboard.version.isEmpty ? 'غير متاح' : dashboard.version,
              ),
              _DetailLine(
                icon: connection.isConnected ? Icons.check_circle_outline : Icons.link_off,
                label: 'الاتصال',
                value: connection.isConnected ? 'متصل' : 'غير متصل',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  _logout();
                },
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('تغيير الراوتر'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _measureSpeed(TrafficProvider traffic, String? selectedName) async {
    final connection = context.read<ConnectionProvider>();
    if (!connection.isConnected || selectedName == null) {
      _message('اتصل بالراوتر واختر واجهة أولاً.', error: true);
      return;
    }
    final received = await traffic.sampleNow();
    if (!mounted) return;
    if (received) {
      _message('تم تحديث قياس حركة الواجهة اللحظي. هذا ليس اختباراً لأقصى سرعة الإنترنت.');
    } else {
      _message('لم تصل قراءة جديدة من الواجهة. تحقق من صلاحيات API والاتصال.', error: true);
    }
  }

  Future<void> _showDiagnosis({
    required ConnectionProvider connection,
    required DashboardProvider dashboard,
    required TrafficProvider traffic,
    required String? selectedName,
    required RosInterface? selectedInterface,
  }) async {
    final latest = selectedName == null || (traffic.history[selectedName]?.isEmpty ?? true)
        ? null
        : traffic.history[selectedName]!.last;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: NovaColors.surface,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('البحث عن المشاكل',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('فحص سريع لبيانات الراوتر التي يستطيع التطبيق قراءتها.',
                  style: TextStyle(color: NovaColors.muted, height: 1.5)),
              const SizedBox(height: 14),
              _DiagnosisLine(
                title: 'الاتصال بالراوتر',
                detail: connection.isConnected ? 'متصل' : 'غير متصل',
                ok: connection.isConnected,
              ),
              _DiagnosisLine(
                title: 'استهلاك المعالج',
                detail: connection.isConnected ? dashboard.cpuLoad + '%' : '—',
                ok: connection.isConnected &&
                    (double.tryParse(dashboard.cpuLoad) ?? 0) < 85,
                neutral: !connection.isConnected,
              ),
              _DiagnosisLine(
                title: 'حرارة الجهاز',
                detail: _temperature(dashboard.cpuTemperature),
                ok: dashboard.cpuTemperature != 'غير متاح',
                neutral: dashboard.cpuTemperature == 'غير متاح',
              ),
              _DiagnosisLine(
                title: 'واجهة المراقبة',
                detail: selectedName ?? 'لم يتم اختيار واجهة',
                ok: selectedInterface?.running == true,
                neutral: selectedInterface == null,
              ),
              _DiagnosisLine(
                title: 'قراءة الحركة الحية',
                detail: latest == null
                    ? 'لم تصل عينة بعد'
                    : 'تنزيل ' + _speed(latest.rx) + ' · رفع ' + _speed(latest.tx),
                ok: latest != null,
                neutral: latest == null,
              ),
              if (connection.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(connection.errorMessage,
                    style: const TextStyle(color: NovaColors.warn, height: 1.4)),
              ],
              if (dashboard.error != null) ...[
                const SizedBox(height: 8),
                Text(dashboard.error!,
                    style: const TextStyle(color: NovaColors.warn, height: 1.4)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  _refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة الفحص'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotifications(TrafficProvider traffic, DashboardProvider dashboard,
      ConnectionProvider connection) async {
    final events = List<NetEvent>.from(traffic.events);
    final messages = <Widget>[];
    if (!connection.isConnected) {
      messages.add(const _NotificationRow(
        icon: Icons.link_off_rounded,
        title: 'الاتصال بالراوتر غير قائم',
        detail: 'تحقق من عنوان الراوتر والشبكة وصلاحيات API.',
        bad: true,
      ));
    }
    if (dashboard.error != null) {
      messages.add(_NotificationRow(
        icon: Icons.warning_amber_rounded,
        title: 'تعذر جلب موارد الجهاز',
        detail: dashboard.error!,
        bad: true,
      ));
    }
    messages.addAll(events.map((event) => _NotificationRow(
      icon: event.bad ? Icons.error_outline_rounded : Icons.notifications_none_rounded,
      title: event.text,
      detail: TimeOfDay.fromDateTime(event.t).format(context),
      bad: event.bad,
    )));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: NovaColors.surface,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.72,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('الإشعارات',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                if (messages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text('لا توجد تنبيهات مسجلة.',
                          style: TextStyle(color: NovaColors.muted)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => messages[index],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCloudInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.cloud_outlined, size: 42, color: NovaColors.primary),
        title: const Text('NOVA Cloud'),
        content: const Text(
          'الاتصال السحابي غير مهيأ في هذه النسخة. للدخول من خارج الشبكة يلزم إعداد بوابة آمنة أو VPN وخدمة وسيطة موثوقة. لا تفتح منافذ إدارة الراوتر مباشرة على الإنترنت.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _onFeature(_FeatureItem item) {
    if (!item.isAvailable) {
      showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: Icon(item.icon, color: item.color, size: 38),
          title: Text(item.title),
          content: Text(item.unavailableMessage,
              style: const TextStyle(height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
      return;
    }
    item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final traffic = context.watch<TrafficProvider>();
    final broadband = context.watch<SubscribersProvider>();
    final hotspot = context.watch<HotspotProvider>();

    final watchedName = traffic.watched.isEmpty ? null : traffic.watched.first;
    final selectedName = watchedName != null &&
            traffic.interfaces.any((item) => item.name == watchedName)
        ? watchedName
        : traffic.interfaces.isEmpty
            ? null
            : traffic.interfaces.first.name;
    final selectedItems = selectedName == null
        ? <RosInterface>[]
        : traffic.interfaces.where((item) => item.name == selectedName).toList();
    final selectedInterface = selectedItems.isEmpty ? null : selectedItems.first;
    final samples = selectedName == null
        ? const <TrafficSample>[]
        : traffic.history[selectedName] ?? const <TrafficSample>[];
    final latest = samples.isEmpty ? null : samples.last;
    final cpu = (double.tryParse(dashboard.cpuLoad) ?? 0).clamp(0, 100).toDouble();
    final storageRatio = dashboard.storageUsedRatio;
    final physicalPorts = traffic.interfaces.where(_isPhysical).toList();
    final activeCount = broadband.onlineCount + hotspot.activeCount;
    final notificationsCount = traffic.events.length +
        (connection.isConnected ? 0 : 1) +
        (dashboard.error == null ? 0 : 1);

    final features = <_FeatureItem>[
      _FeatureItem(
        title: 'البرودباند',
        icon: Icons.router_rounded,
        color: NovaColors.primary,
        count: broadband.error == null ? broadband.all.length.toString() : '—',
        detail: broadband.error == null
            ? broadband.onlineCount.toString() + ' متصل'
            : 'تعذر التحميل',
        onTap: () => _openSection(2, const PppoeScreen()),
      ),
      _FeatureItem(
        title: 'الأكتف',
        icon: Icons.bolt_rounded,
        color: NovaColors.success,
        count: broadband.error == null && hotspot.error == null
            ? activeCount.toString()
            : '—',
        detail: 'جلسات نشطة',
        onTap: () => _openSection(2, const PppoeScreen()),
      ),
      _FeatureItem(
        title: 'هوتسبوت',
        icon: Icons.wifi_tethering_rounded,
        color: NovaColors.cyan,
        count: hotspot.error == null ? hotspot.users.length.toString() : '—',
        detail: hotspot.error == null
            ? hotspot.activeCount.toString() + ' جلسة نشطة'
            : 'تعذر التحميل',
        onTap: () => _openSection(3, const HotspotScreen()),
      ),
      _FeatureItem(
        title: 'يوزر منجر',
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFFFFC477),
        count: '—',
        detail: 'غير مهيأ',
        isAvailable: false,
        unavailableMessage: 'قسم MikroTik User Manager غير مربوط بعد بواجهة إدارة فعلية في هذا الإصدار. لم يتم عرض رقم وهمي أو تنفيذ أي تغيير.',
        onTap: () {},
      ),
      _FeatureItem(
        title: 'نسخة/استعادة',
        icon: Icons.settings_backup_restore_rounded,
        color: const Color(0xFF9CB8FF),
        count: '—',
        detail: 'نسخ الإعدادات',
        isAvailable: false,
        unavailableMessage: 'واجهة النسخ والاستعادة الكاملة لم تكتمل بعد؛ لذلك هذا الاختصار معلّم بوضوح وغير مفعّل بدل إعطاء انطباع كاذب عن وجود نسخة احتياطية.',
        onTap: () {},
      ),
      _FeatureItem(
        title: 'الإضافات',
        icon: Icons.extension_rounded,
        color: const Color(0xFFC4B5FD),
        count: '4',
        detail: 'أدوات مرتبطة',
        onTap: () => _openSection(4, const ToolsScreen()),
      ),
      _FeatureItem(
        title: 'الإشعارات',
        icon: Icons.notifications_active_outlined,
        color: const Color(0xFFFF8795),
        count: notificationsCount.toString(),
        detail: 'تنبيه مسجل',
        onTap: () => _showNotifications(traffic, dashboard, connection),
      ),
      _FeatureItem(
        title: 'المبيعات',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF77D8B4),
        count: '—',
        detail: 'غير مرتبط',
        isAvailable: false,
        unavailableMessage: 'المبيعات والفوترة تحتاجان إلى قاعدة بيانات تجارية وربط واضح بالمشتركين. لا توجد بيانات مبيعات موثوقة لعرضها في الوقت الحالي.',
        onTap: () {},
      ),
      _FeatureItem(
        title: 'تكامل واتساب',
        icon: Icons.chat_rounded,
        color: const Color(0xFF72D7A2),
        count: '—',
        detail: 'غير مهيأ',
        isAvailable: false,
        unavailableMessage: 'تكامل واتساب الآلي غير مهيأ بعد بمزود موثوق ورقم مصرح به. لا يتم إرسال أي رسائل من هذا الاختصار.',
        onTap: () {},
      ),
      _FeatureItem(
        title: 'قطع البث',
        icon: Icons.settings_input_antenna_rounded,
        color: const Color(0xFF79C7F4),
        count: '—',
        detail: 'غير مرتبط',
        isAvailable: false,
        unavailableMessage: 'إدارة أجهزة البث والأبراج تحتاج إلى ربط API أو SNMP خاص بنوع أجهزة الراديو المستخدمة. هذا القسم غير مفعّل بدل عرض بيانات غير دقيقة.',
        onTap: () {},
      ),
    ];

    return Scaffold(
      backgroundColor: NovaColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: NovaColors.primary,
          backgroundColor: NovaColors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(13, 4, 13, 24),
            children: [
              _buildHeader(connection),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _VitalCard(
                      icon: Icons.memory_rounded,
                      title: 'المعالج',
                      value: connection.isConnected ? cpu.toStringAsFixed(0) + '%' : '—',
                      color: !connection.isConnected
                          ? NovaColors.muted
                          : cpu >= 85
                              ? NovaColors.danger
                              : NovaColors.primary,
                      progress: connection.isConnected ? cpu / 100 : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VitalCard(
                      icon: Icons.electrical_services_rounded,
                      title: 'الفولط',
                      value: _voltage(dashboard.voltage),
                      color: NovaColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VitalCard(
                      icon: Icons.device_thermostat_rounded,
                      title: 'الحرارة',
                      value: _temperature(dashboard.cpuTemperature),
                      color: NovaColors.warn,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _CompactInfoCard(
                          height: 65,
                          icon: Icons.schedule_rounded,
                          label: 'مدة التشغيل',
                          value: connection.isConnected ? dashboard.uptime : '—',
                          color: NovaColors.cyan,
                        ),
                        const SizedBox(height: 8),
                        _DeviceCard(
                          boardName: dashboard.boardName,
                          version: dashboard.version,
                        ),
                        const SizedBox(height: 8),
                        _StorageCard(
                          height: 104,
                          used: _storage(dashboard.usedStorageBytes),
                          total: _storage(dashboard.totalStorageBytes),
                          progress: storageRatio,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 7,
                    child: _InternetCard(
                      height: 270,
                      interfaces: traffic.interfaces,
                      selectedName: selectedName,
                      selectedInterface: selectedInterface,
                      latest: latest,
                      onSelect: connection.isConnected
                          ? (name) => traffic.selectInterface(name)
                          : null,
                      onMeasure: () => _measureSpeed(traffic, selectedName),
                      onAdjust: () => _openPage(const QueuesScreen()),
                      isConnected: connection.isConnected,
                      formatSpeed: _speed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _NetworkClockBar(
                time: dashboard.routerTime,
                date: dashboard.routerDate,
                connected: connection.isConnected,
              ),
              const SizedBox(height: 14),
              _TroubleshootingBanner(
                onTap: () => _showDiagnosis(
                  connection: connection,
                  dashboard: dashboard,
                  traffic: traffic,
                  selectedName: selectedName,
                  selectedInterface: selectedInterface,
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  const Expanded(
                    child: Text('الإدارة الرئيسية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  Text(
                    connection.isConnected ? 'متصل بالراوتر' : 'بانتظار الاتصال',
                    style: TextStyle(
                      color: connection.isConnected ? NovaColors.success : NovaColors.warn,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: features.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) => _FeatureTile(
                  item: features[index],
                  onTap: () => _onFeature(features[index]),
                ),
              ),
              const SizedBox(height: 17),
              _PortsCard(
                ports: physicalPorts,
                selectedName: selectedName,
                connected: connection.isConnected,
                onSelect: (name) => traffic.selectInterface(name),
                onOpenAll: () => _openSection(1, const InterfacesScreen()),
              ),
              const SizedBox(height: 10),
              _CloudFooter(
                connected: connection.isConnected,
                onTap: _showCloudInfo,
              ),
              if (dashboard.error != null || broadband.error != null || hotspot.error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NovaColors.warn.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NovaColors.warn.withOpacity(.25)),
                  ),
                  child: Text(
                    'بعض البيانات لم تُحمّل. تحقق من اتصال الراوتر وصلاحيات API، ثم اسحب الشاشة للأسفل لإعادة المحاولة.',
                    style: const TextStyle(color: NovaColors.warn, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ConnectionProvider connection) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            tooltip: 'قطع الاتصال',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: NovaColors.text),
          ),
          Expanded(
            child: InkWell(
              onTap: _showRouterMenu,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            connection.routerIdentity.isEmpty ? 'NOVA' : connection.routerIdentity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: NovaColors.primary, size: 22),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: connection.isConnected ? NovaColors.success : NovaColors.danger,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          connection.isConnected ? 'NOVA · متصل بالراوتر' : 'NOVA · غير متصل',
                          style: const TextStyle(color: NovaColors.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: connection.isConnected ? _refresh : null,
            icon: const Icon(Icons.refresh_rounded, color: NovaColors.text),
          ),
        ],
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final double? progress;

  const _VitalCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 99,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: NovaColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: NovaColors.muted, fontSize: 11)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: NovaColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ],
        ),
      );
}

class _CompactInfoCard extends StatelessWidget {
  final double height;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CompactInfoCard({
    required this.height,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: NovaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: NovaColors.muted, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}

class _DeviceCard extends StatelessWidget {
  final String boardName;
  final String version;

  const _DeviceCard({required this.boardName, required this.version});

  @override
  Widget build(BuildContext context) => Container(
        height: 85,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: NovaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              children: [
                Icon(Icons.developer_board_rounded, color: NovaColors.primary, size: 16),
                SizedBox(width: 5),
                Expanded(
                  child: Text('الجهاز والإصدار',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: NovaColors.muted, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              boardName == 'غير متصل' ? 'غير متصل' : boardName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              version.isEmpty ? 'RouterOS —' : 'RouterOS ' + version,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: NovaColors.muted, fontSize: 10),
            ),
          ],
        ),
      );
}

class _StorageCard extends StatelessWidget {
  final double height;
  final String used;
  final String total;
  final double? progress;

  const _StorageCard({
    required this.height,
    required this.used,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: NovaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              children: [
                Icon(Icons.storage_rounded, color: NovaColors.cyan, size: 16),
                SizedBox(width: 5),
                Expanded(
                  child: Text('التخزين المستخدم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: NovaColors.muted, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(used,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            Text('من ' + total,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: NovaColors.muted, fontSize: 10)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress ?? 0.0,
                minHeight: 5,
                backgroundColor: NovaColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(NovaColors.cyan),
              ),
            ),
          ],
        ),
      );
}

class _InternetCard extends StatelessWidget {
  final double height;
  final List<RosInterface> interfaces;
  final String? selectedName;
  final RosInterface? selectedInterface;
  final TrafficSample? latest;
  final ValueChanged<String>? onSelect;
  final VoidCallback onMeasure;
  final VoidCallback onAdjust;
  final bool isConnected;
  final String Function(double) formatSpeed;

  const _InternetCard({
    required this.height,
    required this.interfaces,
    required this.selectedName,
    required this.selectedInterface,
    required this.latest,
    required this.onSelect,
    required this.onMeasure,
    required this.onAdjust,
    required this.isConnected,
    required this.formatSpeed,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF222342), NovaColors.surface, Color(0xFF121B2B)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.language_rounded, color: NovaColors.cyan, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text('سرعة النت',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                Icon(Icons.auto_graph_rounded, color: NovaColors.primary, size: 17),
              ],
            ),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: selectedName,
              isExpanded: true,
              iconSize: 18,
              decoration: const InputDecoration(
                labelText: 'واجهة المراقبة',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                border: OutlineInputBorder(),
              ),
              hint: const Text('اختر الواجهة', style: TextStyle(fontSize: 11)),
              style: const TextStyle(color: NovaColors.text, fontSize: 12),
              items: interfaces
                  .map((item) => DropdownMenuItem<String>(
                        value: item.name,
                        child: Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
              onChanged: onSelect,
            ),
            const SizedBox(height: 9),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _SpeedValue(
                      icon: Icons.south_rounded,
                      label: 'تنزيل',
                      value: isConnected && latest != null
                          ? formatSpeed(latest!.rx)
                          : '—',
                      color: NovaColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SpeedValue(
                      icon: Icons.north_rounded,
                      label: 'رفع',
                      value: isConnected && latest != null
                          ? formatSpeed(latest!.tx)
                          : '—',
                      color: NovaColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isConnected ? onMeasure : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('قياس السرعة', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: isConnected ? onAdjust : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('ضبط السرعة', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  selectedInterface?.running == true
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: selectedInterface?.running == true ? NovaColors.success : NovaColors.warn,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    selectedInterface?.running == true
                        ? 'الواجهة تعمل'
                        : selectedInterface == null
                            ? 'لا توجد قراءة'
                            : 'الواجهة غير نشطة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: NovaColors.muted, fontSize: 9),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SpeedValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SpeedValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: NovaColors.surface2.withOpacity(.9),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: NovaColors.muted, fontSize: 10)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      );
}

class _NetworkClockBar extends StatelessWidget {
  final String time;
  final String date;
  final bool connected;

  const _NetworkClockBar({
    required this.time,
    required this.date,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: NovaColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: NovaColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: NovaColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                time == 'غير متاح' ? 'وقت الشبكة: غير متاح' : 'وقت الشبكة: ' + time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_month_rounded, color: NovaColors.cyan, size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                date == 'غير متاح' ? '—' : date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: NovaColors.muted, fontSize: 11),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? NovaColors.success : NovaColors.danger,
              ),
            ),
          ],
        ),
      );
}

class _TroubleshootingBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _TroubleshootingBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: 91,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [Color(0xFF31275F), Color(0xFF171B2C), Color(0xFF121A29)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: NovaColors.primary.withOpacity(.5)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 7,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: .08,
                    child: Center(
                      child: Text('0101 1010 0011 0101',
                          style: TextStyle(
                              color: NovaColors.cyan,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        height: 63,
                        width: 63,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [NovaColors.primary, Color(0xFF4F93D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: NovaColors.primary.withOpacity(.22),
                              blurRadius: 17,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.search_rounded,
                            size: 37, color: Colors.white),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('البحث عن المشاكل',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                            SizedBox(height: 4),
                            Text('فحص الاتصال والمعالج والخط المختار',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: NovaColors.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded, color: NovaColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _FeatureItem {
  final String title;
  final IconData icon;
  final Color color;
  final String count;
  final String detail;
  final bool isAvailable;
  final String unavailableMessage;
  final VoidCallback onTap;

  const _FeatureItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.detail,
    required this.onTap,
    this.isAvailable = true,
    this.unavailableMessage = '',
  });
}

class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  final VoidCallback onTap;

  const _FeatureTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: NovaColors.surface,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: NovaColors.border),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  item.color.withOpacity(.10),
                  NovaColors.surface,
                  NovaColors.surface,
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 47,
                      height: 47,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withOpacity(.15),
                        border: Border.all(color: item.color.withOpacity(.28)),
                      ),
                      child: Icon(item.icon, color: item.color, size: 25),
                    ),
                    if (!item.isAvailable)
                      Positioned(
                        top: -5,
                        left: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: NovaColors.surface2,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: NovaColors.border),
                          ),
                          child: const Text('قريباً',
                              style: TextStyle(fontSize: 8, color: NovaColors.muted)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(item.count,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: item.color, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(item.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: NovaColors.muted, fontSize: 9)),
              ],
            ),
          ),
        ),
      );
}

class _PortsCard extends StatelessWidget {
  final List<RosInterface> ports;
  final String? selectedName;
  final bool connected;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenAll;

  const _PortsCard({
    required this.ports,
    required this.selectedName,
    required this.connected,
    required this.onSelect,
    required this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NovaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NovaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('الواجهات والمنافذ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                TextButton(
                  onPressed: onOpenAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('عرض الكل', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (!connected)
              const Text('اتصل بالراوتر لعرض حالة المنافذ.',
                  style: TextStyle(color: NovaColors.muted, fontSize: 12))
            else if (ports.isEmpty)
              const Text('لم تصل معلومات المنافذ بعد.',
                  style: TextStyle(color: NovaColors.muted, fontSize: 12))
            else
              Wrap(
                spacing: 7,
                runSpacing: 8,
                children: ports.map((port) {
                  final isSelected = port.name == selectedName;
                  final isUp = port.running;
                  final tint = port.disabled
                      ? NovaColors.warn
                      : isUp
                          ? NovaColors.success
                          : NovaColors.muted;
                  return InkWell(
                    onTap: () => onSelect(port.name),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 72),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? NovaColors.primary.withOpacity(.13) : NovaColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? NovaColors.primary : NovaColors.border,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cable_rounded,
                            color: tint,
                            size: 21,
                          ),
                          const SizedBox(height: 4),
                          Text(port.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(
                            port.disabled ? 'معطل' : isUp ? 'متصل' : 'فارغ',
                            style: TextStyle(fontSize: 9, color: tint),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 9),
            const Row(
              children: [
                Icon(Icons.circle, color: NovaColors.success, size: 8),
                SizedBox(width: 5),
                Text('متصل', style: TextStyle(color: NovaColors.muted, fontSize: 10)),
                SizedBox(width: 13),
                Icon(Icons.circle, color: NovaColors.muted, size: 8),
                SizedBox(width: 5),
                Text('فارغ', style: TextStyle(color: NovaColors.muted, fontSize: 10)),
                SizedBox(width: 13),
                Icon(Icons.circle, color: NovaColors.warn, size: 8),
                SizedBox(width: 5),
                Text('معطل', style: TextStyle(color: NovaColors.muted, fontSize: 10)),
              ],
            ),
          ],
        ),
      );
}

class _CloudFooter extends StatelessWidget {
  final bool connected;
  final VoidCallback onTap;

  const _CloudFooter({required this.connected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: NovaColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NovaColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: NovaColors.primary.withOpacity(.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_outlined, color: NovaColors.primary, size: 23),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('اتصل بالكلاود',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(
                        'للدخول إلى شبكتك من أي مكان في العالم\nالكلاود غير مهيأ · ' +
                            (connected ? 'الراوتر متصل محلياً' : 'الراوتر غير متصل'),
                        style: const TextStyle(color: NovaColors.muted, fontSize: 10, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: NovaColors.warn,
                      size: 17,
                    ),
                    const SizedBox(height: 4),
                    const Text('إعداد',
                        style: TextStyle(color: NovaColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          children: [
            Icon(icon, color: NovaColors.primary, size: 19),
            const SizedBox(width: 10),
            SizedBox(
              width: 82,
              child: Text(label, style: const TextStyle(color: NovaColors.muted, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      );
}

class _DiagnosisLine extends StatelessWidget {
  final String title;
  final String detail;
  final bool ok;
  final bool neutral;

  const _DiagnosisLine({
    required this.title,
    required this.detail,
    required this.ok,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = neutral ? NovaColors.muted : ok ? NovaColors.success : NovaColors.warn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            neutral ? Icons.remove_circle_outline : ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(detail,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool bad;

  const _NotificationRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.bad,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NovaColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NovaColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: bad ? NovaColors.warn : NovaColors.cyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(detail, style: const TextStyle(color: NovaColors.muted, fontSize: 10, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}
