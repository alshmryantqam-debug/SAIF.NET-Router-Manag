import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mikrotik_session_model.dart';
import '../providers/sessions_provider.dart';
import '../theme.dart';
import '../widgets/particle_matrix_bg.dart';
import '../widgets/nova_ui_kit.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionsProvider>().fetchAllSessions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatBytes(String value) {
    final bytes = int.tryParse(value) ?? 0;
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} كيلوبايت';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميغابايت';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} غيغابايت';
  }

  Future<void> _kick(SessionsProvider provider, MikrotikSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('تأكيد فصل الجلسة'),
        content: Text('سيتم فصل "${session.name}" عن الراوتر الآن.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            child: const Text('فصل الجلسة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await provider.kickSession(session);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'تم فصل الجلسة والتحقق من تحديث القائمة من الراوتر.' : provider.errorMessage),
      backgroundColor: success ? AppTheme.successColor : AppTheme.dangerColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionsProvider>(
      builder: (context, state, child) {
        final all = [...state.pppoeSessions, ...state.hotspotSessions];
        final query = _searchQuery.trim().toLowerCase();
        final visible = all.where((session) =>
          session.name.toLowerCase().contains(query) ||
          session.address.toLowerCase().contains(query) ||
          session.callerId.toLowerCase().contains(query)
        ).toList(growable: false);

        return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('الجلسات النشطة المباشرة'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات من الراوتر',
            onPressed: state.isLoading ? null : () => state.fetchAllSessions(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ParticleMatrixBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو عنوان الشبكة أو عنوان الجهاز',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: _countPanel('المجموع', all.length, const Color(0xFF00E5FF))),
                  const SizedBox(width: 8),
                  Expanded(child: _countPanel('اتصال مشفّر', state.pppoeSessions.length, const Color(0xFF8B5CF6))),
                  const SizedBox(width: 8),
                  Expanded(child: _countPanel('نقطة اتصال', state.hotspotSessions.length, const Color(0xFFE040FB))),
                ]),
              ),
              if (state.errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: NovaTechPanel(
                    accentColor: AppTheme.dangerColor,
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.errorMessage, style: const TextStyle(color: Colors.white70))),
                      TextButton(
                        onPressed: state.isLoading ? null : () => state.fetchAllSessions(),
                        child: const Text('المحاولة مجدداً'),
                      ),
                    ]),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: state.isLoading && all.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                    : !state.isConnected && all.isEmpty
                        ? const Center(child: Text('اتصل بالراوتر لعرض الجلسات الحقيقية.', style: TextStyle(color: Colors.white70)))
                        : visible.isEmpty
                            ? Center(child: Text(
                                query.isEmpty ? 'لا توجد جلسات نشطة حالياً على الراوتر.' : 'لا توجد نتائج مطابقة.',
                                style: const TextStyle(color: Colors.white70),
                              ))
                            : RefreshIndicator(
                                onRefresh: state.fetchAllSessions,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) => _sessionCard(state, visible[index]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _countPanel(String label, int count, Color accent) => NovaTechPanel(
    accentColor: accent,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Column(children: [
      Text('$count', style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  );

  Widget _sessionCard(SessionsProvider provider, MikrotikSession session) {
    final accent = session.isPppoe ? const Color(0xFF00E5FF) : const Color(0xFFE040FB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NovaTechPanel(
        accentColor: accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(session.isPppoe ? Icons.router_rounded : Icons.wifi_rounded, color: accent),
            const SizedBox(width: 8),
            Expanded(child: Text(session.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(session.isPppoe ? 'اشتراك مباشر' : 'نقطة اتصال', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          _detailRow('عنوان الشبكة', session.address),
          _detailRow('عنوان الجهاز', session.callerId.isEmpty ? '—' : session.callerId),
          _detailRow('مدة الاتصال', session.uptime),
          _detailRow('البيانات الواردة', _formatBytes(session.bytesIn)),
          _detailRow('البيانات الصادرة', _formatBytes(session.bytesOut)),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: () => _kick(provider, session),
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('فصل الجلسة'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      SizedBox(width: 112, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))),
    ]),
  );
}
