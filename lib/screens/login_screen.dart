import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../models/router_config.dart';
import '../providers/connection_provider.dart';
import '../services/storage_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl = TextEditingController(text: 'My Router');
  final _hostCtrl = TextEditingController(text: '192.168.88.1');
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();

  String _version = 'v7';
  bool _ssl = true;
  bool _save = true;
  bool _busy = false;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  //  VALIDATION
  // ═══════════════════════════════════════════════
  String? _validateHost(String host) {
    if (host.isEmpty) return 'أدخل عنوان الراوتر';

    // IPv4
    final ipv4 = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (ipv4.hasMatch(host)) {
      final parts = host.split('.').map(int.parse);
      if (parts.any((p) => p > 255)) return 'عنوان IP غير صحيح';
      return null;
    }

    // IPv6 (simplified)
    if (host.contains(':')) return null;

    // DNS name
    final dns = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]{1,253}$');
    if (dns.hasMatch(host)) return null;

    return 'عنوان غير صالح';
  }

  // ═══════════════════════════════════════════════
  //  CONNECT
  // ═══════════════════════════════════════════════
  Future<void> _connect() async {
    if (_busy) return;

    final host = _hostCtrl.text.trim();
    final hostError = _validateHost(host);
    if (hostError != null) {
      setState(() => _error = hostError);
      return;
    }

    if (_userCtrl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم المستخدم');
      return;
    }

    if (_passCtrl.text.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = 'جارٍ التحقق من الاتصال...';
    });

    final port = _version == 'v7'
        ? (_ssl ? 443 : 80)
        : (_ssl ? 8729 : 8728);

    final config = RouterConfigModel(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim().isEmpty ? 'Router' : _nameCtrl.text.trim(),
      host: host,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      version: _version,
      port: port,
      ssl: _ssl,
    );

    try {
      final service = ref.read(mikrotikProvider);
      final result = await service.connect(config);

      if (!mounted) return;

      setState(() => _status = result.message);

      // Update provider state
      ref.read(connectedProvider.notifier).state = true;

      // Save if requested
      if (_save) {
        try {
          await StorageService().save(config);
        } catch (_) {
          // Saving failed but connection is OK
        }
      }

      // Navigate after short delay to show success
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) context.go('/app');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _status = null;
        _busy = false;
      });
    }
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  Widget _field(
    TextEditingController c,
    String label, {
    bool secret = false,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: secret,
        enabled: !_busy,
        keyboardType: secret
            ? TextInputType.text
            : (label.contains('IP') || label.contains('DNS'))
                ? TextInputType.url
                : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
        ),
      ),
    );
  }

  Widget _statusBox(String msg, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.router,
                size: 70,
                color: Color(0xFF00D9FF),
              ),
              const SizedBox(height: 12),
              const Text(
                'TikPlus ULTRA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'المنصة الاحترافية لإدارة MikroTik',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 28),

              _field(_nameCtrl, 'اسم الراوتر', icon: Icons.label_outline),
              _field(_hostCtrl, 'IP أو DNS', icon: Icons.dns_outlined),
              _field(_userCtrl, 'اسم المستخدم',
                  icon: Icons.person_outline),
              _field(_passCtrl, 'كلمة المرور',
                  secret: true, icon: Icons.lock_outline),

              // Version selector
              DropdownButtonFormField<String>(
                value: _version,
                decoration: const InputDecoration(
                  labelText: 'إصدار RouterOS',
                  prefixIcon: Icon(Icons.memory),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'v7',
                    child: Text('v7 — REST API (موصى به)'),
                  ),
                  DropdownMenuItem(
                    value: 'v6',
                    child: Text('v6 — Binary API'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _version = v ?? 'v7'),
              ),
              const SizedBox(height: 8),

              // SSL toggle
              SwitchListTile(
                title: Text(
                  _version == 'v7'
                      ? 'HTTPS (REST API v7)'
                      : 'SSL (Binary API v6)',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: _ssl
                    ? null
                    : const Text(
                        '⚠️ غير آمن — للشبكات المحلية فقط',
                        style: TextStyle(
                          color: Color(0xFFFFB020),
                          fontSize: 11,
                        ),
                      ),
                value: _ssl,
                onChanged: _busy ? null : (v) => setState(() => _ssl = v),
              ),

              // Save toggle
              SwitchListTile(
                title: const Text(
                  'حفظ بيانات الراوتر بأمان',
                  style: TextStyle(fontSize: 14),
                ),
                value: _save,
                onChanged: _busy ? null : (v) => setState(() => _save = v),
              ),

              const SizedBox(height: 16),

              // Error box
              if (_error != null)
                _statusBox(_error!, const Color(0xFFFF3B5C),
                    Icons.error_outline),

              // Status box
              if (_status != null && _error == null)
                _statusBox(_status!, const Color(0xFF00D9FF),
                    Icons.sync_rounded),

              const SizedBox(height: 16),

              // Connect button
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _connect,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded),
                  label: Text(
                    _busy ? 'جارٍ الاتصال...' : 'اختبار الاتصال والدخول',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'TikPlus ULTRA · v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
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
