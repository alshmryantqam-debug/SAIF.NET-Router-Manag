import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/radio_management_launcher.dart';
import '../theme.dart';

class RadioAccessScreen extends StatefulWidget {
  const RadioAccessScreen({super.key});

  @override
  State<RadioAccessScreen> createState() => _RadioAccessScreenState();
}

class _RadioAccessScreenState extends State<RadioAccessScreen> {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'saifnet.radio_remote_access.v1';
  final _name = TextEditingController();
  final _localUrl = TextEditingController();
  final _remoteUrl = TextEditingController();
  final _launcher = const RadioManagementLauncher();
  final List<Map<String, String>> _devices = [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _localUrl.dispose();
    _remoteUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _devices.addAll(decoded.whereType<Map>().map((e) =>
              Map<String, String>.from(e.map((k, v) =>
                  MapEntry(k.toString(), v.toString())))));
        }
      }
    } catch (_) {
      _message = 'تعذر تحميل قائمة الأجهزة المحفوظة.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() => _storage.write(
      key: _storageKey, value: jsonEncode(_devices));

  Future<void> _addDevice() async {
    _name.clear();
    _localUrl.clear();
    _remoteUrl.clear();
    final formKey = GlobalKey<FormState>();
    final added = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة جهاز لاسلكي'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الجهاز / الموقع'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'اكتب اسماً للجهاز'
                    : null,
              ),
              TextFormField(
                controller: _localUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'رابط الإدارة المحلي',
                  hintText: 'http://192.168.1.20',
                ),
                validator: (v) => RadioManagementLauncher.isSafeManagementUrl(
                        v ?? '', remote: false)
                    ? null
                    : 'أدخل رابط http/https صالحاً بدون اسم مستخدم أو كلمة مرور بالرابط',
              ),
              TextFormField(
                controller: _remoteUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'رابط VPN / النفق الخارجي (اختياري)',
                  hintText: 'https://radio-site.example.com',
                ),
                validator: (v) => v == null || v.trim().isEmpty ||
                        RadioManagementLauncher.isSafeManagementUrl(
                            v, remote: true)
                    ? null
                    : 'الرابط الخارجي يجب أن يستخدم HTTPS وبدون بيانات دخول بالرابط',
              ),
              const SizedBox(height: 10),
              const Text(
                'التطبيق لا ينشئ VPN أو نفقاً تلقائياً. جهّز WireGuard/Tailscale أو نفقاً خاصاً آمناً أولاً. لا توجّه منفذ إدارة الصحن مباشرةً إلى الإنترنت.',
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, {
                'id': DateTime.now().microsecondsSinceEpoch.toString(),
                'name': _name.text.trim(),
                'localUrl': _localUrl.text.trim(),
                'remoteUrl': _remoteUrl.text.trim(),
              });
            },
            child: const Text('حفظ الجهاز'),
          ),
        ],
      ),
    );
    if (added == null || !mounted) return;
    setState(() {
      _devices.removeWhere((d) => d['localUrl'] == added['localUrl']);
      _devices.add(added);
      _message = 'تم حفظ بيانات الجهاز على الهاتف.';
    });
    await _save();
  }

  Future<void> _openDevice(Map<String, String> device, {required bool remote}) async {
    final remoteUrl = device['remoteUrl'] ?? '';
    final url = remote && remoteUrl.isNotEmpty ? remoteUrl : device['localUrl'] ?? '';
    final actuallyRemote = remote && remoteUrl.isNotEmpty;
    try {
      final opened = await _launcher.open(url, remote: actuallyRemote);
      if (!mounted) return;
      setState(() => _message = opened
          ? 'تم طلب فتح لوحة الجهاز في المتصفح.'
          : 'لم يتمكن النظام من فتح الرابط.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('ArgumentError: ', ''));
    }
  }

  Future<void> _deleteDevice(Map<String, String> device) async {
    setState(() => _devices.removeWhere((d) => d['id'] == device['id']));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصحون عن بُعد'),
        actions: [
          IconButton(
            tooltip: 'إضافة جهاز',
            onPressed: _addDevice,
            icon: const Icon(Icons.add_link_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDevice,
        icon: const Icon(Icons.add),
        label: const Text('إضافة جهاز'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.public_rounded, color: Colors.white, size: 30),
                      SizedBox(height: 8),
                      Text('لوحات NanoStation والسكترات',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text('افتح واجهة الجهاز في المتصفح عبر شبكة الإدارة المحلية أو اتصال VPN/نفق مشفّر.',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'الأمان: لا تُخزّن كلمات المرور داخل الرابط. الروابط الخارجية تقبل HTTPS فقط. الوصول الفعلي يتطلب أن يكون VPN أو النفق مُهيّأ ويصل إلى عنوان الجهاز.',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_message!, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                if (_devices.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('لا توجد أجهزة محفوظة بعد. أضف اسم الجهاز والرابط المحلي، ويمكنك إضافة رابط HTTPS خارجي عند إعداد النفق.'),
                    ),
                  ),
                ..._devices.map((device) {
                  final hasRemote = (device['remoteUrl'] ?? '').isNotEmpty;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.settings_input_antenna_rounded, color: AppColors.secondary, size: 28),
                          const SizedBox(width: 10),
                          Expanded(child: Text(device['name'] ?? 'جهاز لاسلكي',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          IconButton(
                            tooltip: 'حذف الجهاز',
                            onPressed: () => _deleteDevice(device),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ]),
                        Text('محلي: ${device['localUrl'] ?? '—'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(hasRemote ? 'الوصول الخارجي: مُعدّ' : 'الوصول الخارجي: غير مُعدّ',
                            style: TextStyle(color: hasRemote ? AppColors.success : AppColors.warning, fontSize: 12)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed: () => _openDevice(device, remote: false),
                            icon: const Icon(Icons.home_work_outlined),
                            label: const Text('فتح محلياً'),
                          ),
                          FilledButton.icon(
                            onPressed: hasRemote ? () => _openDevice(device, remote: true) : null,
                            icon: const Icon(Icons.vpn_lock_rounded),
                            label: const Text('فتح عن بُعد'),
                          ),
                        ]),
                      ]),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
