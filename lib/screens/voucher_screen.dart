import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hotspot_user.dart';
import '../models/voucher.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/ultra_input.dart';

class VoucherScreen extends ConsumerStatefulWidget {
  const VoucherScreen({super.key});

  @override
  ConsumerState<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends ConsumerState<VoucherScreen> {
  final _countCtrl = TextEditingController(text: '10');
  final _prefixCtrl = TextEditingController(text: 'VIP');
  final _profileCtrl = TextEditingController(text: 'default');
  final _nameLenCtrl = TextEditingController(text: '6');
  final _passLenCtrl = TextEditingController(text: '4');
  final _uptimeCtrl = TextEditingController();
  final _bytesCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  bool _samePassword = false;
  bool _numericOnly = true;
  bool _busy = false;
  String? _error;
  String? _status;

  List<Voucher> _generated = [];
  final List<Voucher> _successful = [];
  int _failed = 0;

  @override
  void dispose() {
    _countCtrl.dispose();
    _prefixCtrl.dispose();
    _profileCtrl.dispose();
    _nameLenCtrl.dispose();
    _passLenCtrl.dispose();
    _uptimeCtrl.dispose();
    _bytesCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (count < 1 || count > 1000) {
      setState(() => _error = 'العدد يجب أن يكون بين 1 و 1000');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = 'جاري توليد $count كرت...';
      _generated = [];
      _successful.clear();
      _failed = 0;
    });

    final list = VoucherGenerator.generate(
      count: count,
      profile: _profileCtrl.text.trim().isEmpty
          ? 'default'
          : _profileCtrl.text.trim(),
      nameLength: int.tryParse(_nameLenCtrl.text.trim()) ?? 6,
      passwordLength: int.tryParse(_passLenCtrl.text.trim()) ?? 4,
      prefix: _prefixCtrl.text.trim(),
      samePassword: _samePassword,
      numericOnly: _numericOnly,
      limitUptime: _uptimeCtrl.text.trim(),
      limitBytes: int.tryParse(_bytesCtrl.text.trim()) ?? 0,
      comment: _commentCtrl.text.trim(),
    );

    final service = ref.read(mikrotikProvider);

    for (var i = 0; i < list.length; i++) {
      if (!mounted) return;
      setState(() => _status = 'جاري إنشاء ${i + 1} من ${list.length}...');

      final v = list[i];
      try {
        await service.addHotspotUser(
          HotspotUser(
            name: v.username,
            password: v.password,
            profile: v.profile,
            comment: v.comment,
            limitUptime: v.limitUptime,
            limitBytesTotal: v.limitBytes,
          ),
        );
        _successful.add(v);
      } catch (_) {
        _failed++;
      }
    }

    if (!mounted) return;

    ref.invalidate(hotspotUsersProvider);

    setState(() {
      _busy = false;
      _status = null;
      _generated = List.from(_successful);
      if (_failed > 0) {
        _error = 'تم إنشاء ${_successful.length} بنجاح، فشل $_failed';
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء ${_successful.length} كرت'
            '${_failed > 0 ? " · فشل $_failed" : ""}',
          ),
          backgroundColor: _failed > 0
              ? AppColors.warning
              : AppColors.success,
        ),
      );
    }
  }

  Future<void> _copyAll() async {
    if (_generated.isEmpty) return;
    final text = _generated.map((v) => v.line).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ كل الكروت للحافظة'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _copyOne(Voucher v) async {
    await Clipboard.setData(
      ClipboardData(text: '${v.username} / ${v.password}'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ: ${v.username}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.confirmation_number_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'توليد دفعة كروت Hotspot دفعة واحدة (حتى 1000 كرت)',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            title: 'إعدادات التوليد',
            children: [
              Row(
                children: [
                  Expanded(
                    child: UltraInput(
                      controller: _countCtrl,
                      label: 'عدد الكروت',
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                      enabled: !_busy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: UltraInput(
                      controller: _prefixCtrl,
                      label: 'البادئة',
                      icon: Icons.tag_rounded,
                      enabled: !_busy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              UltraInput(
                controller: _profileCtrl,
                label: 'البروفايل',
                icon: Icons.category_outlined,
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: UltraInput(
                      controller: _nameLenCtrl,
                      label: 'طول الاسم',
                      icon: Icons.text_fields_rounded,
                      keyboardType: TextInputType.number,
                      enabled: !_busy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: UltraInput(
                      controller: _passLenCtrl,
                      label: 'طول كلمة المرور',
                      icon: Icons.password_rounded,
                      keyboardType: TextInputType.number,
                      enabled: !_busy,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            title: 'خيارات إضافية',
            children: [
              _switch(
                'كلمة المرور نفسها (البطاقة)',
                _samePassword,
                (v) => setState(() => _samePassword = v),
              ),
              _switch(
                'أرقام فقط',
                _numericOnly,
                (v) => setState(() => _numericOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            title: 'قيود اختيارية',
            children: [
              UltraInput(
                controller: _uptimeCtrl,
                label: 'مدة الصلاحية',
                icon: Icons.timer_outlined,
                hint: 'مثال: 1d أو 12h أو 30m',
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              UltraInput(
                controller: _bytesCtrl,
                label: 'حد التحميل بالبايت',
                icon: Icons.data_usage_outlined,
                hint: 'مثال: 1073741824 = 1GB',
                keyboardType: TextInputType.number,
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              UltraInput(
                controller: _commentCtrl,
                label: 'تعليق للكروت',
                icon: Icons.comment_outlined,
                enabled: !_busy,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.danger.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _status!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: _busy ? 'جاري التوليد...' : 'توليد الكروت',
            icon: Icons.auto_awesome_rounded,
            loading: _busy,
            onPressed: _generate,
          ),
          if (_generated.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'الكروت المولدة',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_generated.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _copyAll,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('نسخ الكل'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              itemCount: _generated.length,
              itemBuilder: (_, i) => _VoucherCard(
                voucher: _generated[i],
                onTap: () => _copyOne(_generated[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: _busy ? null : onChange,
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback onTap;

  const _VoucherCard({required this.voucher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.12),
                AppColors.secondary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  voucher.profile,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                voucher.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                voucher.password,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Row(
                children: [
                  Icon(
                    Icons.copy_rounded,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'نسخ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}