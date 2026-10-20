import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api/routeros_client.dart';
import '../models/subscriber.dart';
import '../providers/subscribers_provider.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class PppoeScreen extends StatefulWidget {
  const PppoeScreen({super.key});
  @override
  State<PppoeScreen> createState() => _PppoeScreenState();
}

class _PppoeScreenState extends State<PppoeScreen> {
  final _search = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SubscribersProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.successColor : AppTheme.dangerColor,
      ));
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) _snack(success);
    } on RosException catch (e) {
      _snack(e.message, success: false);
    } catch (_) {
      _snack('تعذرت العملية. تحقق من الاتصال وصلاحيات الراوتر.', success: false);
    }
  }

  int _count(SubscribersProvider p, SubFilter f) => p.all.where((s) {
    switch (f) {
      case SubFilter.all: return true;
      case SubFilter.online: return s.online;
      case SubFilter.offline: return !s.online;
      case SubFilter.expired: return s.expired;
      case SubFilter.expiringSoon: return !s.expired && s.daysLeft != null && s.daysLeft! <= 3;
      case SubFilter.disabled: return s.disabled;
    }
  }).length;

  String _filterName(SubFilter f) {
    switch (f) {
      case SubFilter.all: return 'الكل';
      case SubFilter.online: return 'متصل';
      case SubFilter.offline: return 'غير متصل';
      case SubFilter.expired: return 'منتهي';
      case SubFilter.expiringSoon: return 'ينتهي قريباً';
      case SubFilter.disabled: return 'معطل';
    }
  }

  String _date(DateTime? date) {
    if (date == null) return 'غير محدد';
    final d = date.toLocal();
    return d.year.toString().padLeft(4, '0') + '-' +
      d.month.toString().padLeft(2, '0') + '-' +
      d.day.toString().padLeft(2, '0');
  }

  Color _expiryColor(Subscriber s) {
    if (s.expired) return AppTheme.dangerColor;
    if (s.daysLeft != null && s.daysLeft! <= 3) return AppTheme.warningColor;
    return AppTheme.successColor;
  }

  String _expiryText(Subscriber s) {
    if (s.expiry == null) return 'تاريخ الانتهاء غير محدد';
    if (s.expired) return 'منتهي منذ ' + s.daysLeft!.abs().toString() + ' يوم';
    if (s.daysLeft == 0) return 'ينتهي اليوم';
    return 'متبقي ' + s.daysLeft.toString() + ' يوم';
  }

  String _password() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#%';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _addForm(SubscribersProvider p) async {
    final key = GlobalKey<FormState>();
    final name = TextEditingController();
    final pass = TextEditingController(text: _password());
    final phone = TextEditingController();
    final price = TextEditingController();
    String? profile = p.profiles.isEmpty ? null : p.profiles.first;
    int months = 1;
    bool hidePass = true;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
          child: Form(key: key, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة مشترك PPPoE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم المستخدم' : null),
              TextFormField(controller: pass, obscureText: hidePass, decoration: InputDecoration(
                labelText: 'كلمة السر',
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'توليد كلمة سر', icon: const Icon(Icons.auto_awesome),
                    onPressed: () => setSheet(() => pass.text = _password())),
                  IconButton(icon: Icon(hidePass ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setSheet(() => hidePass = !hidePass)),
                ]),
              ), validator: (v) => v == null || v.isEmpty ? 'أدخل كلمة السر' : null),
              DropdownButtonFormField<String>(
                value: profile, decoration: const InputDecoration(labelText: 'البروفايل / السرعة'),
                items: p.profiles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setSheet(() => profile = v),
                validator: (v) => v == null ? 'لا توجد بروفايلات متاحة' : null,
              ),
              TextFormField(controller: phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)')),
              TextFormField(controller: price, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعر المتوقع (اختياري)'),
                validator: (v) => v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null
                  ? 'أدخل السعر كرقم صحيح' : null),
              DropdownButtonFormField<int>(
                value: months, decoration: const InputDecoration(labelText: 'مدة الاشتراك'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('شهر واحد')),
                  DropdownMenuItem(value: 3, child: Text('3 أشهر')),
                  DropdownMenuItem(value: 6, child: Text('6 أشهر')),
                  DropdownMenuItem(value: 12, child: Text('12 شهراً')),
                ],
                onChanged: (v) => setSheet(() => months = v ?? 1),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _adding ? null : () async {
                  if (!(key.currentState?.validate() ?? false) || profile == null) return;
                  setState(() => _adding = true);
                  try {
                    await p.add(name: name.text.trim(), password: pass.text, profile: profile!,
                      phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                      price: price.text.trim().isEmpty ? null : int.parse(price.text.trim()), months: months);
                    if (mounted) { Navigator.pop(sheet); _snack('تمت إضافة المشترك بنجاح'); }
                  } on RosException catch (e) {
                    if (mounted) _snack(e.message, success: false);
                  } catch (_) {
                    if (mounted) _snack('تعذرت إضافة المشترك. تحقق من البيانات والاتصال.', success: false);
                  } finally {
                    if (mounted) setState(() => _adding = false);
                  }
                },
                icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة المشترك'),
              ),
            ],
          ))),
        ),
      )),
    );
    name.dispose(); pass.dispose(); phone.dispose(); price.dispose();
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: OutlinedButton.icon(
      onPressed: onTap, icon: Icon(icon), label: Text(label),
      style: OutlinedButton.styleFrom(alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
    ),
  );

  Future<void> _actions(SubscribersProvider p, Subscriber s) async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('تاريخ الانتهاء: ' + _date(s.expiry), textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          _action(Icons.calendar_month, 'تمديد شهر', () async { Navigator.pop(sheet); await _run(() => p.extend(s), 'تم تمديد الاشتراك لشهر'); }),
          _action(Icons.date_range, 'تمديد 3 أشهر', () async { Navigator.pop(sheet); await _run(() => p.extend(s, months: 3), 'تم تمديد الاشتراك لثلاثة أشهر'); }),
          _action(s.disabled ? Icons.check_circle : Icons.block, s.disabled ? 'تفعيل المشترك' : 'تعطيل المشترك', () async {
            Navigator.pop(sheet); await _run(() => p.setDisabled(s, !s.disabled), s.disabled ? 'تم تفعيل المشترك' : 'تم تعطيل المشترك');
          }),
          _action(Icons.link_off, 'فصل الجلسة', s.online ? () async {
            Navigator.pop(sheet); await _run(() => p.kick(s), 'تم فصل جلسة المشترك');
          } : null),
          _action(Icons.speed, 'تغيير السرعة / البروفايل', () async {
            if (p.profiles.isEmpty) { _snack('لا توجد بروفايلات من الراوتر', success: false); return; }
            String chosen = p.profiles.contains(s.profile) ? s.profile : p.profiles.first;
            final result = await showDialog<String>(context: sheet, builder: (dialog) => StatefulBuilder(
              builder: (dialog, setDialog) => AlertDialog(
                title: const Text('تغيير السرعة'),
                content: DropdownButtonFormField<String>(
                  value: chosen, items: p.profiles.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) { if (v != null) setDialog(() => chosen = v); },
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
                  FilledButton(onPressed: () => Navigator.pop(dialog, chosen), child: const Text('تطبيق')),
                ],
              ),
            ));
            if (result != null && sheet.mounted) {
              Navigator.pop(sheet);
              await _run(() => p.changeProfile(s, result), 'تم تغيير البروفايل وفصل الجلسة لتطبيق السرعة');
            }
          }),
          _action(Icons.chat, 'تذكير عبر واتساب', () async {
            Navigator.pop(sheet);
            final message = 'مرحباً ' + s.name + '، نذكّرك بأن اشتراك الإنترنت ينتهي بتاريخ ' +
              _date(s.expiry) + '. يرجى التواصل لتجديد الاشتراك. شكراً لك.';
            try {
              final uri = Uri.https('wa.me', '/', {'text': message});
              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!launched && mounted) _snack('تعذر فتح واتساب', success: false);
            } catch (_) { _snack('تعذر فتح واتساب. تحقق من تثبيته أو توفر المتصفح.', success: false); }
          }),
          _action(Icons.delete_outline, 'حذف المشترك', () async {
            final ok = await showDialog<bool>(context: sheet, builder: (dialog) => AlertDialog(
              title: const Text('تأكيد حذف المشترك'),
              content: Text('هل تريد حذف ' + s.name + ' نهائياً من الراوتر؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerColor),
                  onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف')),
              ],
            ));
            if (ok == true && sheet.mounted) {
              Navigator.pop(sheet); await _run(() => p.remove(s), 'تم حذف المشترك');
            }
          }),
        ])),
      )),
    );
  }

  Widget _stat(IconData icon, String title, String value, Color color) => Expanded(child: GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
    child: Column(children: [
      Icon(icon, color: color), const SizedBox(height: 7),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ]),
  ));

  Widget _pill(IconData icon, String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: color), const SizedBox(width: 4),
    Text(text, style: TextStyle(fontSize: 12, color: color)),
  ]);

  Widget _subscriber(Subscriber s, SubscribersProvider p) {
    final color = _expiryColor(s);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _actions(p, s),
        child: GlassCard(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(
              shape: BoxShape.circle, color: s.online ? AppTheme.successColor : AppTheme.textSecondary)),
            const SizedBox(width: 9),
            Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
            if (s.expiryScheduled) const Padding(
              padding: EdgeInsetsDirectional.only(start: 5),
              child: Tooltip(message: 'جدولة الانتهاء مفعّلة على الراوتر',
                child: Icon(Icons.shield_rounded, size: 17, color: AppTheme.successColor)),
            ),
            Text(s.online ? 'متصل' : 'غير متصل', style: TextStyle(fontSize: 12,
              color: s.online ? AppTheme.successColor : AppTheme.textSecondary)),
            const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 7, children: [
            _pill(Icons.speed, s.profile, AppTheme.primaryColor),
            _pill(Icons.event_available, _expiryText(s), color),
            if (s.disabled) _pill(Icons.block, 'معطل', AppTheme.dangerColor),
          ]),
          if (s.online && (s.address != null || s.uptime != null)) ...[
            const SizedBox(height: 10), const Divider(height: 1), const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 6, children: [
              if (s.address != null) _pill(Icons.lan, 'IP: ' + s.address!, AppTheme.textSecondary),
              if (s.uptime != null) _pill(Icons.timer_outlined, 'مدة الاتصال: ' + s.uptime!, AppTheme.textSecondary),
            ]),
          ],
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SubscribersProvider>();
    final users = p.visible;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة البرودباند'), actions: [
        IconButton(tooltip: 'تحديث القائمة', onPressed: p.loading ? null : p.load, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addForm(p), backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('إضافة مشترك', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: p.load, color: AppTheme.primaryColor,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 100), children: [
          Row(children: [
            _stat(Icons.wifi, 'متصلون الآن', p.onlineCount.toString(), AppTheme.successColor),
            const SizedBox(width: 7),
            _stat(Icons.event_busy, 'منتهون', p.expiredCount.toString(), AppTheme.dangerColor),
            const SizedBox(width: 7),
            _stat(Icons.payments_outlined, 'الإيراد المتوقع', p.expectedRevenue.toString(), AppTheme.warningColor),
          ]),
          const SizedBox(height: 14),
          GlassCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1), child: TextField(
            controller: _search, onChanged: p.setQuery,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو رقم الهاتف', prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () {
                _search.clear(); p.setQuery('');
              }),
            ),
          )),
          const SizedBox(height: 12),
          SizedBox(height: 43, child: ListView(scrollDirection: Axis.horizontal,
            children: SubFilter.values.map((f) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 7),
              child: ChoiceChip(
                selected: p.filter == f, label: Text(_filterName(f) + ' (' + _count(p, f).toString() + ')'),
                onSelected: (_) => p.setFilter(f),
                selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                side: BorderSide(color: p.filter == f ? AppTheme.primaryColor : AppTheme.cardBorderColor),
              ),
            )).toList(),
          )),
          const SizedBox(height: 12),
          if (p.loading && p.all.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else if (p.error != null && p.all.isEmpty)
            GlassCard(child: Column(children: [
              const Icon(Icons.cloud_off, size: 40, color: AppTheme.dangerColor),
              const SizedBox(height: 8),
              Text(p.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.dangerColor)),
              OutlinedButton.icon(onPressed: p.load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
            ]))
          else if (users.isEmpty)
            const GlassCard(child: Center(child: Padding(padding: EdgeInsets.all(20),
              child: Text('لا يوجد مشتركون مطابقون للبحث أو الفلتر', textAlign: TextAlign.center))))
          else
            ...users.map((s) => _subscriber(s, p)),
          if (p.error != null && p.all.isNotEmpty)
            Text(p.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.dangerColor)),
        ]),
      ),
    );
  }
}
