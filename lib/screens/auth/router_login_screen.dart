import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/router_config.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/cyber_text_field.dart';
import '../../widgets/nova_ui_kit.dart';
import '../../widgets/particle_matrix_bg.dart';

const _cyan = Color(0xFF00E5FF);
const _violet = Color(0xFFE040FB);
const _red = Color(0xFFFF5370);
const _muted = Color(0xFF8EA2B8);

class RouterLoginScreen extends ConsumerStatefulWidget {
  const RouterLoginScreen({super.key});

  @override
  ConsumerState<RouterLoginScreen> createState() => _RouterLoginScreenState();
}

class _RouterLoginScreenState extends ConsumerState<RouterLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'الراوتر الرئيسي');
  final _ipController = TextEditingController(text: '192.168.88.1');
  final _portController = TextEditingController(text: '8728');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController();

  late final AnimationController _radarController;
  RouterVersion _version = RouterVersion.v6;
  bool _useSsl = false;
  bool _obscurePassword = true;
  bool _rememberRouter = true;
  bool _busy = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _loadLastRouter();
  }

  Future<void> _loadLastRouter() async {
    try {
      final last = await ref.read(storageProvider).getLastUsed();
      if (!mounted || last == null) return;
      setState(() {
        _nameController.text = last.name;
        _ipController.text = last.host;
        _userController.text = last.username;
        _passController.text = last.password;
        _version = last.version;
        _useSsl = last.useSsl;
        _portController.text = last.version == RouterVersion.v7
            ? (last.useSsl ? '443' : '80')
            : (last.useSsl ? '8729' : '8728');
      });
    } catch (_) {
      // Keep safe defaults if no saved profile is available.
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _changeVersion(RouterVersion version) {
    setState(() {
      _version = version;
      if (version == RouterVersion.v7) {
        _useSsl = true;
        _portController.text = '443';
      } else if (version == RouterVersion.v6) {
        _useSsl = false;
        _portController.text = '8728';
      } else {
        _useSsl = false;
        _portController.text = '80';
      }
      _error = null;
    });
  }

  Future<void> _establishUplink() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final host = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'رقم المنفذ يجب أن يكون بين 1 و65535');
      return;
    }

    final profile = RouterProfile(
      id: const Uuid().v4(),
      name: _nameController.text.trim().isEmpty
          ? host
          : _nameController.text.trim(),
      host: host,
      username: _userController.text.trim(),
      password: _passController.text,
      restPort: _version == RouterVersion.v7
          ? port
          : (_useSsl ? 443 : 80),
      apiPort: _version == RouterVersion.v6
          ? port
          : (_useSsl ? 8729 : 8728),
      version: _version,
      useSsl: _useSsl,
    );

    setState(() {
      _busy = true;
      _error = null;
      _status = 'جارٍ إنشاء قناة الاتصال والتحقق من بيانات الراوتر...';
    });

    try {
      // Use the real Riverpod notifier and MikrotikService; no simulated success.
      final ok = await ref.read(connectionProvider.notifier).connect(profile);
      if (!mounted) return;

      if (ok) {
        if (!_rememberRouter) {
          await ref.read(storageProvider).delete(profile.id);
        }
        setState(() {
          _busy = false;
          _status = 'تم التحقق من الاتصال بنجاح';
        });
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted) context.goNamed('dashboard');
      } else {
        final message =
            ref.read(connectionProvider).error ?? 'رفض الراوتر الاتصال';
        setState(() {
          _busy = false;
          _status = null;
          _error = message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopStatus(),
                      const SizedBox(height: 18),
                      _buildAnimatedLock(),
                      const SizedBox(height: 18),
                      const Text(
                        'SECURE ROUTER UPLINK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.6,
                          shadows: [Shadow(color: _cyan, blurRadius: 16)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'MIKROTIK CORE // AUTHENTICATION TERMINAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 9,
                          height: 1.6,
                          letterSpacing: 1.1,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProtocolSelector(),
                      const SizedBox(height: 12),
                      NovaTechPanel(
                        accentColor: _cyan,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel('01 / ROUTER ENDPOINT'),
                            CyberTextField(
                              controller: _nameController,
                              label: 'ROUTER DESIGNATION (OPTIONAL)',
                              icon: Icons.hub_rounded,
                              accentColor: _cyan,
                              enabled: !_busy,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: CyberTextField(
                                    controller: _ipController,
                                    label: 'HOST IP / DNS',
                                    icon: Icons.router_rounded,
                                    keyboardType: TextInputType.url,
                                    accentColor: _cyan,
                                    enabled: !_busy,
                                    validator: (value) {
                                      final host = value?.trim() ?? '';
                                      if (host.isEmpty) return 'أدخل عنوان الراوتر';
                                      if (host.contains(' ') || host.length < 4) {
                                        return 'تحقق من عنوان IP أو DNS';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 4,
                                  child: CyberTextField(
                                    controller: _portController,
                                    label: 'PORT',
                                    icon: Icons.cable_rounded,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    accentColor: _cyan,
                                    enabled: !_busy,
                                    validator: (value) {
                                      final n = int.tryParse(value ?? '');
                                      if (n == null || n < 1 || n > 65535) {
                                        return 'منفذ غير صالح';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            _sectionLabel('02 / ACCESS CREDENTIALS'),
                            CyberTextField(
                              controller: _userController,
                              label: 'ADMINISTRATOR ID',
                              icon: Icons.person_outline_rounded,
                              accentColor: _cyan,
                              enabled: !_busy,
                              validator: (value) =>
                                  (value?.trim().isNotEmpty ?? false)
                                      ? null
                                      : 'أدخل اسم المستخدم',
                            ),
                            CyberTextField(
                              controller: _passController,
                              label: 'AUTHENTICATION KEY',
                              icon: Icons.key_rounded,
                              isPassword: _obscurePassword,
                              accentColor: _cyan,
                              enabled: !_busy,
                              suffix: IconButton(
                                tooltip: _obscurePassword
                                    ? 'إظهار كلمة المرور'
                                    : 'إخفاء كلمة المرور',
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        }),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: _cyan,
                                  size: 19,
                                ),
                              ),
                              validator: (value) =>
                                  (value?.isNotEmpty ?? false)
                                      ? null
                                      : 'أدخل كلمة المرور',
                            ),
                            _buildRememberToggle(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_error != null) ...[
                        _messagePanel(_error!, _red, Icons.gpp_bad_rounded),
                        const SizedBox(height: 12),
                      ],
                      if (_status != null && _error == null) ...[
                        _messagePanel(
                          _status!,
                          _cyan,
                          _busy ? Icons.sync_rounded : Icons.verified_rounded,
                          loading: _busy,
                        ),
                        const SizedBox(height: 12),
                      ],
                      NovaCyberButton(
                        text: _busy ? 'AUTHENTICATING UPLINK...' : 'INITIALIZE SECURE UPLINK',
                        icon: _busy
                            ? Icons.sync_rounded
                            : Icons.sensors_rounded,
                        color: _cyan,
                        height: 68,
                        onPressed: _busy ? null : _establishUplink,
                      ),
                      const SizedBox(height: 14),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatus() {
    return Row(
      children: [
        const Icon(Icons.memory_rounded, color: _cyan, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'NOVA // NETWORK CONTROL',
            style: TextStyle(
              color: _cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _violet.withOpacity(.45)),
            color: _violet.withOpacity(.07),
          ),
          child: const Text(
            'SECURE MODE',
            style: TextStyle(
              color: _violet,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedLock() {
    return SizedBox(
      width: 142,
      height: 142,
      child: AnimatedBuilder(
        animation: _radarController,
        builder: (context, child) {
          final angle = _radarController.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withOpacity(.16),
                      blurRadius: 34,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: angle,
                child: CustomPaint(
                  size: const Size(138, 138),
                  painter: _RadarRingPainter(
                    color: _cyan,
                    segments: 8,
                    strokeWidth: 2,
                  ),
                ),
              ),
              Transform.rotate(
                angle: -angle * 0.7,
                child: CustomPaint(
                  size: const Size(106, 106),
                  painter: _RadarRingPainter(
                    color: _violet,
                    segments: 6,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xDD0B1423),
                  border: Border.all(color: _cyan.withOpacity(.45)),
                ),
                child: Icon(
                  _busy ? Icons.sync_rounded : Icons.lock_outline_rounded,
                  color: _cyan,
                  size: 34,
                ),
              ),
              Positioned(
                bottom: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: const Color(0xFF070B14),
                  child: Text(
                    _busy ? 'VERIFYING' : 'CORE LOCKED',
                    style: const TextStyle(
                      color: _cyan,
                      fontSize: 8,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProtocolSelector() {
    return NovaTechPanel(
      accentColor: _violet,
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('PROTOCOL MATRIX'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RouterVersion.values.map((version) {
              final selected = _version == version;
              final label = switch (version) {
                RouterVersion.auto => 'AUTO DETECT',
                RouterVersion.v6 => 'ROS v6 / API',
                RouterVersion.v7 => 'ROS v7 / REST',
              };
              return GestureDetector(
                onTap: _busy ? null : () => _changeVersion(version),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? _violet.withOpacity(.13) : Colors.black.withOpacity(.22),
                    border: Border.all(
                      color: selected ? _violet : Colors.white.withOpacity(.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: selected ? _violet : _muted,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _busy
                ? null
                : () {
                    setState(() {
                      _useSsl = !_useSsl;
                      if (_version == RouterVersion.v7) {
                        _portController.text = _useSsl ? '443' : '80';
                      } else {
                        _portController.text = _useSsl ? '8729' : '8728';
                      }
                    });
                  },
            child: Row(
              children: [
                Icon(
                  _useSsl ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: _useSsl ? _cyan : _muted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _useSsl ? 'TLS ENCRYPTION ENABLED' : 'TLS ENCRYPTION DISABLED',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Switch(
                  value: _useSsl,
                  activeColor: _cyan,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _useSsl = value;
                            if (_version == RouterVersion.v7) {
                              _portController.text = value ? '443' : '80';
                            } else {
                              _portController.text = value ? '8729' : '8728';
                            }
                          });
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _busy
            ? null
            : () => setState(() => _rememberRouter = !_rememberRouter),
        child: Row(
          children: [
            Icon(
              _rememberRouter
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: _rememberRouter ? _cyan : _muted,
              size: 20,
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'تذكّر ملف الراوتر على هذا الجهاز',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ),
            const Icon(Icons.phonelink_lock_rounded, color: _muted, size: 17),
          ],
        ),
      ),
    );
  }

  Widget _messagePanel(
    String message,
    Color color,
    IconData icon, {
    bool loading = false,
  }) {
    return NovaTechPanel(
      accentColor: color,
      padding: const EdgeInsets.all(13),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
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
          'SAIF.NET // NOVA CONTROL PLANE',
          style: TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        SizedBox(height: 5),
        Text(
          'RouterOS v6 Binary API · RouterOS v7 REST API',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF596A80), fontSize: 9),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: _cyan),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarRingPainter extends CustomPainter {
  const _RadarRingPainter({
    required this.color,
    required this.segments,
    required this.strokeWidth,
  });

  final Color color;
  final int segments;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - strokeWidth;
    final sweep = (2 * math.pi / segments) * .48;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        (2 * math.pi / segments) * i,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.segments != segments ||
      oldDelegate.strokeWidth != strokeWidth;
}
