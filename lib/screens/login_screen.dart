import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/router_config.dart';
import '../providers/connection_provider.dart';
import '../theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/ultra_input.dart';
import '../widgets/version_selector.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController(text: 'الراوتر الرئيسي');
  final _hostCtrl = TextEditingController(text: '192.168.88.1');
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '80');

  RouterVersion _version = RouterVersion.auto;
  bool _useSsl = false;
  bool _obscurePass = true;
  bool _rememberMe = true;
  bool _busy = false;
  String? _error;
  String? _status;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final storage = ref.read(storageProvider);
    final last = await storage.getLastUsed();
    if (last != null && mounted) {
      setState(() {
        _nameCtrl.text = last.name;
        _hostCtrl.text = last.host;
        _userCtrl.text = last.username;
        _passCtrl.text = last.password;
        _version = last.version;
        _useSsl = last.useSsl;
        if (last.version == RouterVersion.v7) {
          _portCtrl.text = last.useSsl ? '443' : '80';
        } else if (last.version == RouterVersion.v6) {
          _portCtrl.text = last.useSsl ? '8729' : '8728';
        } else {
          _portCtrl.text = '80';
        }
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _onVersionChanged(RouterVersion v) {
    setState(() {
      _version = v;
      if (v == RouterVersion.v7) {
        _useSsl = true;
        _portCtrl.text = '443';
      } else if (v == RouterVersion.v6) {
        _useSsl = false;
        _portCtrl.text = '8728';
      } else {
        _useSsl = false;
        _portCtrl.text = '80';
      }
    });
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
      _status = 'جاري الاتصال بالراوتر...';
    });

    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 80;

    final profile = RouterProfile(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim().isEmpty ? host : _nameCtrl.text.trim(),
      host: host,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      restPort: _version == RouterVersion.v7 ? port : 80,
      apiPort: _version == RouterVersion.v6 ? port : 8728,
      version: _version,
      useSsl: _useSsl,
    );

    final notifier = ref.read(connectionProvider.notifier);
    setState(() => _status = 'جاري التحقق من بيانات الدخول...');

    final ok = await notifier.connect(profile);

    if (!mounted) return;

    if (ok) {
      setState(() => _status = 'تم الاتصال بنجاح');

      if (!_rememberMe) {
        await ref.read(storageProvider).delete(profile.id);
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) context.go('/dashboard');
    } else {
      final err = ref.read(connectionProvider).error ?? 'فشل الاتصال';
      setState(() {
        _error = err;
        _status = null;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4, -0.6),
                  radius: 1.4,
                  colors: [Color(0xFF0A1B3D), AppColors.bgDeep],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: _glow(AppColors.primary, 280),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: _glow(AppColors.secondary, 260),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: size.height - 80,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBrand(),
                          const SizedBox(height: 32),
                          _buildCard(),
                          const SizedBox(height: 20),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.18),
              color.withOpacity(0.04),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.glow(AppColors.primary, opacity: 0.4),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppGradients.primary.createShader(bounds),
          child: const Text(
            'TikPlus ULTRA',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'المنصة الاحترافية لإدارة MikroTik',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.85),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.lan_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'الاتصال بالراوتر',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'أدخل بيانات الراوتر للبدء',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'نظام الراوتر',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          VersionSelector(
            value: _version,
            onChanged: _busy ? null : _onVersionChanged,
          ),
          const SizedBox(height: 16),
          UltraInput(
            controller: _nameCtrl,
            label: 'اسم الراوتر (اختياري)',
            icon: Icons.label_outline_rounded,
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          UltraInput(
            controller: _hostCtrl,
            label: 'IP أو DNS',
            icon: Icons.dns_outlined,
            keyboardType: TextInputType.url,
            enabled: !_busy,
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return 'أدخل عنوان الراوتر';
              if (s.length < 4) return 'العنوان قصير جداً';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: UltraInput(
                  controller: _portCtrl,
                  label: 'المنفذ',
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                  enabled: !_busy,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 65535) {
                      return 'منفذ غير صحيح';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _buildSslToggle()),
            ],
          ),
          const SizedBox(height: 12),
          UltraInput(
            controller: _userCtrl,
            label: 'اسم المستخدم',
            icon: Icons.person_outline_rounded,
            enabled: !_busy,
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'أدخل اسم المستخدم';
              return null;
            },
          ),
          const SizedBox(height: 12),
          UltraInput(
            controller: _passCtrl,
            label: 'كلمة المرور',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            enabled: !_busy,
            validator: (v) {
              if ((v ?? '').isEmpty) return 'أدخل كلمة المرور';
              return null;
            },
            suffix: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          const SizedBox(height: 14),
          _buildRememberToggle(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _buildStatusBox(
              message: _error!,
              color: AppColors.danger,
              icon: Icons.error_outline_rounded,
            ),
          ],
          if (_status != null && _error == null) ...[
            const SizedBox(height: 14),
            _buildStatusBox(
              message: _status!,
              color: AppColors.primary,
              icon: Icons.sync_rounded,
              loading: true,
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: _busy ? 'جاري الاتصال...' : 'اتصال بالراوتر',
            icon: Icons.bolt_rounded,
            loading: _busy,
            onPressed: _connect,
          ),
        ],
      ),
    );
  }

  Widget _buildSslToggle() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _useSsl
              ? AppColors.success.withOpacity(0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _useSsl ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: _useSsl ? AppColors.success : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _useSsl ? 'SSL آمن' : 'بدون SSL',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: _useSsl,
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() {
                        _useSsl = v;
                        if (_version == RouterVersion.v7) {
                          _portCtrl.text = v ? '443' : '80';
                        } else if (_version == RouterVersion.v6) {
                          _portCtrl.text = v ? '8729' : '8728';
                        }
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberToggle() {
    return InkWell(
      onTap: _busy ? null : () => setState(() => _rememberMe = !_rememberMe),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppDurations.normal,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _rememberMe ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      _rememberMe ? AppColors.primary : AppColors.border,
                  width: 1.6,
                ),
              ),
              child: _rememberMe
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.bgDeep,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            const Text(
              'حفظ بيانات الراوتر بأمان',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBox({
    required String message,
    required Color color,
    required IconData icon,
    bool loading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Text(
          'TikPlus ULTRA · الإصدار 1.0.0',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'يدعم RouterOS v6 و v7 · اتصال آمن',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}