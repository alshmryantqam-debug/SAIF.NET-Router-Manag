import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pcc_configuration.dart';
import '../providers/connection_provider.dart';
import '../providers/load_balancing_provider.dart';
import '../services/mikrotik_service.dart';
import '../widgets/cyber_fusion_slider.dart';
import '../widgets/particle_matrix_bg.dart';

const Color _fusionCyan = Color(0xFF00E5FF);
const Color _fusionPink = Color(0xFFE040FB);
const Color _fusionRed = Color(0xFFFF5252);

class LoadBalancingWizardScreen extends ConsumerStatefulWidget {
  const LoadBalancingWizardScreen({super.key});

  @override
  ConsumerState<LoadBalancingWizardScreen> createState() =>
      _LoadBalancingWizardScreenState();
}

class _LoadBalancingWizardScreenState
    extends ConsumerState<LoadBalancingWizardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final TextEditingController _lanController =
      TextEditingController(text: 'bridge-local');
  bool _initialInterfacesHandled = false;
  bool _backupVerified = false;
  bool _rollbackReady = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _lanController.dispose();
    super.dispose();
  }

  void _seedFromRouter(List<InterfaceInfo> interfaces) {
    if (!mounted || !ref.read(connectionProvider).isConnected) return;
    final byName = interfaces.map((item) => item.name).toSet();
    var names = <String>['ether1', 'ether2', 'ether3']
        .where((name) => byName.contains(name))
        .toList();

    if (names.length < 2) {
      names = interfaces
          .where((item) =>
              !item.disabled &&
              item.running &&
              item.name != 'bridge-local' &&
              !item.name.toLowerCase().startsWith('bridge') &&
              !item.name.toLowerCase().contains('loopback'))
          .map((item) => item.name)
          .toSet()
          .take(2)
          .toList();
    }
    if (names.length >= 2 && ref.read(loadBalancingProvider).wans.isEmpty) {
      ref.read(loadBalancingProvider.notifier).setWans(
            names
                .take(3)
                .map((name) => PccWanConfig(
                      interfaceName: name,
                      gateway: '',
                      weight: 1,
                    ))
                .toList(),
          );
    }
  }

  List<String> _candidateInterfaces(
    List<InterfaceInfo> interfaces,
    LoadBalancingState state,
  ) {
    final used = state.wans.map((wan) => wan.interfaceName).toSet();
    return interfaces
        .where((item) =>
            !item.disabled &&
            item.name != state.lanInterface &&
            !used.contains(item.name))
        .map((item) => item.name)
        .toList();
  }

  Future<void> _executeFusion(LoadBalancingState fusion) async {
    if (!_backupVerified || !_rollbackReady || fusion.isApplying) return;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171323),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _fusionPink.withOpacity(0.6)),
        ),
        title: const Text(
          'تأكيد تطبيق PCC على الراوتر',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'سيضيف التطبيق جداول توجيه وقواعد PCC وNAT للواجهات المختارة. '
          'لن يضيف مسارات failover احتياطية. إذا اكتشف قواعد PCC فعالة غير مُدارة '
          'من SAIF.NET فسيرفض التنفيذ لتجنب تداخل القواعد.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _fusionPink,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('أوافق على التنفيذ'),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) return;
    final success = await ref.read(loadBalancingProvider.notifier).apply(
          explicitlyConfirmed: true,
          backupVerified: _backupVerified,
          rollbackPlanAvailable: _rollbackReady,
        );
    if (!mounted) return;
    if (success) {
      final message = ref.read(loadBalancingProvider).message ??
          'اكتمل تنفيذ PCC والتحقق منه.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF174C48),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectionProvider, (previous, next) {
      if (previous?.isConnected != true && next.isConnected) {
        _initialInterfacesHandled = false;
        ref.invalidate(interfacesProvider);
      }
    });

    final fusion = ref.watch(loadBalancingProvider);
    final connection = ref.watch(connectionProvider);
    final interfaceAsync = ref.watch(interfacesProvider);
    final interfaces = interfaceAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <InterfaceInfo>[],
    );

    if (interfaceAsync.hasValue &&
        connection.isConnected &&
        !_initialInterfacesHandled) {
      _initialInterfacesHandled = true;
      final interfaceSnapshot = interfaces;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seedFromRouter(interfaceSnapshot);
      });
    }

    final totalWeight = fusion.totalWeight;
    final selectedNames =
        fusion.wans.map((wan) => wan.interfaceName).toSet();
    final candidates = _candidateInterfaces(interfaces, fusion);
    final canApply = connection.isConnected &&
        fusion.wans.length >= 2 &&
        fusion.wans.length <= 4 &&
        fusion.lanInterface.trim().isNotEmpty &&
        !selectedNames.contains(fusion.lanInterface.trim()) &&
        selectedNames.length == fusion.wans.length &&
        fusion.wans.every((wan) => wan.gateway.trim().isNotEmpty) &&
        _backupVerified &&
        _rollbackReady &&
        !fusion.isApplying;
    final interfaceError =
        interfaceAsync.hasError ? interfaceAsync.error.toString() : '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14).withOpacity(0.72),
        elevation: 0,
        foregroundColor: _fusionCyan,
        title: const Text(
          'PCC FUSION CORE',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            shadows: [Shadow(color: _fusionCyan, blurRadius: 10)],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'إعادة قراءة الواجهات',
            onPressed: connection.isConnected
                ? () {
                    _initialInterfacesHandled = false;
                    ref.invalidate(interfacesProvider);
                  }
                : null,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: ParticleMatrixBg(
        particleCount: 44,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildCore(fusion, connection.isConnected),
                  const SizedBox(height: 12),
                  _buildConnectionState(
                    connection.isConnected,
                    connection.activeProfile?.version.label ??
                        'RouterOS v7 / REST',
                  ),
                  if (interfaceAsync.isLoading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(color: _fusionCyan),
                    const SizedBox(height: 6),
                    const Text(
                      'قراءة الواجهات الفعلية من الراوتر...',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                  if (interfaceAsync.hasError) ...[
                    const SizedBox(height: 12),
                    _messageBox(
                      Icons.warning_amber_rounded,
                      'تعذرت قراءة الواجهات: ' + interfaceError,
                      _fusionRed,
                    ),
                  ],
                  if (fusion.error != null) ...[
                    const SizedBox(height: 12),
                    _messageBox(
                      Icons.error_outline_rounded,
                      fusion.error!,
                      _fusionRed,
                    ),
                  ],
                  if (fusion.message != null) ...[
                    const SizedBox(height: 12),
                    _messageBox(
                      Icons.verified_rounded,
                      fusion.message!,
                      _fusionCyan,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle('01', 'مصادر الطاقة WAN', 'WEIGHTED PCC SOURCES'),
                  const SizedBox(height: 10),
                  if (fusion.wans.isEmpty)
                    _messageBox(
                      Icons.info_outline_rounded,
                      connection.isConnected
                          ? 'لم تُحمّل واجهات بعد. اضغط زر التحديث أعلى الشاشة ثم أضف واجهتين على الأقل.'
                          : 'اتصل بالراوتر أولاً لقراءة الواجهات الحقيقية قبل إعداد الدمج.',
                      Colors.amber,
                    ),
                  for (var index = 0; index < fusion.wans.length; index++) ...[
                    _buildWanEditor(
                      index,
                      fusion.wans[index],
                      fusion,
                      interfaces,
                    ),
                    const SizedBox(height: 2),
                    _weightShareText(fusion.wans[index], totalWeight),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _fusionCyan.withOpacity(0.55)),
                      foregroundColor: _fusionCyan,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: candidates.isEmpty ||
                            fusion.wans.length >= 4 ||
                            !connection.isConnected
                        ? null
                        : () {
                            ref.read(loadBalancingProvider.notifier).addWan(
                                  candidates.first,
                                );
                          },
                    icon: const Icon(Icons.add_link_rounded),
                    label: Text(
                      fusion.wans.length >= 4
                          ? 'MAX WAN SOURCES REACHED'
                          : 'ADD NEW WAN SOURCE',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (connection.isConnected && interfaces.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'تم اكتشاف ' +
                          interfaces.length.toString() +
                          ' واجهة؛ الواجهات العاملة: ' +
                          interfaces
                              .where((item) => item.running && !item.disabled)
                              .map((item) => item.name)
                              .take(8)
                              .join(', '),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _sectionTitle('02', 'مسار الشبكة', 'LAN / GATEWAY ROUTING'),
                  const SizedBox(height: 10),
                  _glassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'واجهة LAN / Bridge',
                          style: TextStyle(
                            color: _fusionCyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lanController,
                          onChanged: ref
                              .read(loadBalancingProvider.notifier)
                              .setLanInterface,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                          decoration: const InputDecoration(
                            hintText: 'bridge-local',
                            helperText:
                                'يجب أن تكون الواجهة موجودة وفعالة على الراوتر',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'أدخل بوابة IPv4 الحقيقية لكل WAN كما تظهر في جدول التوجيه. لن يخمّن التطبيق البوابة تلقائياً.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('03', 'بروتوكول الأمان', 'BACKUP + ROLLBACK'),
                  const SizedBox(height: 8),
                  _glassPanel(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _backupVerified,
                          onChanged: (value) => setState(
                            () => _backupVerified = value ?? false,
                          ),
                          activeColor: _fusionCyan,
                          checkColor: const Color(0xFF070B14),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'أنشأت نسخة احتياطية وتحققت من إمكانية استعادتها',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          subtitle: const Text(
                            'تأكيد يدوي منك؛ التطبيق لا يدّعي أنه أنشأ النسخة.',
                            style: TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const Divider(color: Colors.white12),
                        CheckboxListTile(
                          value: _rollbackReady,
                          onChanged: (value) => setState(
                            () => _rollbackReady = value ?? false,
                          ),
                          activeColor: _fusionCyan,
                          checkColor: const Color(0xFF070B14),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'لدي خطة تراجع ووصول بديل إلى الراوتر',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          subtitle: const Text(
                            'لا تنفذ تغييرات توجيه على شبكة إنتاج دون خطة استعادة.',
                            style: TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _messageBox(
                    Icons.warning_amber_rounded,
                    'التطبيق ينشئ قواعد PCC وجداول توجيه وNAT. لا ينشئ مسارات failover احتياطية. إذا وجد قواعد PCC فعالة غير مُدارة من SAIF.NET فسيتوقف قبل التعديل منعاً لتكرار التصنيف.',
                    Colors.amber,
                  ),
                  const SizedBox(height: 18),
                  _glassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'DEPLOYMENT SUMMARY',
                          style: TextStyle(
                            color: _fusionCyan,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _summaryRow('WAN SOURCES', fusion.wans.length.toString()),
                        _summaryRow('TOTAL WEIGHT', totalWeight.toString()),
                        _summaryRow('CLASSIFIER BUCKETS', totalWeight.toString()),
                        _summaryRow('ROUTING TABLES', fusion.wans.length.toString()),
                        _summaryRow('NAT RULES', fusion.wans.length.toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fusionPink.withOpacity(0.16),
                    disabledBackgroundColor: Colors.white.withOpacity(0.04),
                    foregroundColor: _fusionPink,
                    disabledForegroundColor: Colors.white24,
                    elevation: 0,
                    side: BorderSide(
                      color: canApply ? _fusionPink : Colors.white24,
                      width: 1.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: canApply ? () => _executeFusion(fusion) : null,
                  child: fusion.isApplying
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _fusionPink,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'APPLYING PCC TO ROUTER...',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded, size: 28),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'ENGAGE CORE FUSION',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCore(LoadBalancingState fusion, bool connected) {
    return _glassPanel(
      borderColor: _fusionCyan.withOpacity(0.3),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = _pulseController.value;
              final diameter = 82 + (pulse * 14);
              return Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _fusionCyan.withOpacity(0.35 + pulse * 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _fusionPink.withOpacity(0.16 + pulse * 0.2),
                      blurRadius: 34,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: _fusionCyan.withOpacity(0.12 + (1 - pulse) * 0.18),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.merge_type_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'FUSION REACTOR // PCC',
            style: TextStyle(
              color: _fusionCyan,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            connected ? 'ROUTER LINK ESTABLISHED' : 'ROUTER LINK OFFLINE',
            style: TextStyle(
              color: connected ? const Color(0xFF67F5BE) : _fusionRed,
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'توزيع اتصالات WAN بأوزان نسبية مع تنفيذ محكوم ومراجعة للتعارضات.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWanEditor(
    int index,
    PccWanConfig wan,
    LoadBalancingState fusion,
    List<InterfaceInfo> interfaces,
  ) {
    final usedByOthers = fusion.wans
        .asMap()
        .entries
        .where((entry) => entry.key != index)
        .map((entry) => entry.value.interfaceName)
        .toSet();
    final names = interfaces
        .map((item) => item.name)
        .where((name) => !usedByOthers.contains(name))
        .toSet()
        .toList();
    if (wan.interfaceName.isNotEmpty && !names.contains(wan.interfaceName)) {
      names.add(wan.interfaceName);
    }
    final selected =
        names.contains(wan.interfaceName) ? wan.interfaceName : null;
    final wanNumber = index + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _glassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 33,
                    height: 33,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _fusionCyan.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _fusionCyan.withOpacity(0.4)),
                    ),
                    child: Text(
                      'W' + wanNumber.toString(),
                      style: const TextStyle(
                        color: _fusionCyan,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selected,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF171323),
                      decoration: const InputDecoration(
                        labelText: 'واجهة مصدر الطاقة',
                      ),
                      items: names
                          .map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(loadBalancingProvider.notifier)
                              .updateWan(index, interfaceName: value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey<String>(
                  'gateway-' + index.toString() + '-' + wan.interfaceName,
                ),
                initialValue: wan.gateway,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (value) => ref
                    .read(loadBalancingProvider.notifier)
                    .updateWan(index, gateway: value.trim()),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'بوابة WAN ' +
                      wanNumber.toString() +
                      ' (Gateway IPv4)',
                  hintText: '192.168.1.1',
                  prefixIcon: const Icon(
                    Icons.route_rounded,
                    color: _fusionCyan,
                  ),
                  helperText:
                      'العنوان الذي يستطيع الراوتر الوصول إليه عبر هذا الخط',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CyberFusionSlider(
          interfaceName: wan.interfaceName.isEmpty
              ? 'WAN ' + wanNumber.toString()
              : wan.interfaceName,
          weight: wan.weight,
          onChanged: (value) => ref
              .read(loadBalancingProvider.notifier)
              .updateWan(index, weight: value),
          onRemove: () =>
              ref.read(loadBalancingProvider.notifier).removeWan(index),
        ),
      ],
    );
  }

  Widget _weightShareText(PccWanConfig wan, int totalWeight) {
    final share = totalWeight == 0
        ? '0.0'
        : (wan.weight / totalWeight * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Text(
        'حصة الوزن التقديرية: ' +
            share +
            '% • ليست قياس سرعة فعلياً',
        style: const TextStyle(color: Colors.white54, fontSize: 10),
      ),
    );
  }

  Widget _buildConnectionState(bool connected, String version) {
    return _messageBox(
      connected ? Icons.verified_user_rounded : Icons.link_off_rounded,
      connected
          ? 'متصل • ' + version
          : 'لا يوجد اتصال فعّال بالراوتر. اتصل أولاً ثم أعد قراءة الواجهات.',
      connected ? const Color(0xFF67F5BE) : _fusionRed,
    );
  }

  Widget _sectionTitle(String number, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _fusionCyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _fusionCyan.withOpacity(0.3)),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: _fusionCyan,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _glassPanel({
    required Widget child,
    Color borderColor = const Color(0x553D8FFF),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xCC0B1020),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.07),
                blurRadius: 20,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _messageBox(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 11, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _fusionCyan,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
