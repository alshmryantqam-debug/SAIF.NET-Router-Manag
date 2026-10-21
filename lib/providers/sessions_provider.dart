import 'package:flutter/foundation.dart';

import '../models/mikrotik_session_model.dart';
import 'connection_provider.dart';

class SessionsProvider extends ChangeNotifier {
  final ConnectionProvider connection;

  SessionsProvider(this.connection);

  bool _isLoading = false;
  bool _isConnected = false;
  String _errorMessage = '';
  List<MikrotikSession> _pppoeSessions = const [];
  List<MikrotikSession> _hotspotSessions = const [];

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  List<MikrotikSession> get pppoeSessions => List.unmodifiable(_pppoeSessions);
  List<MikrotikSession> get hotspotSessions => List.unmodifiable(_hotspotSessions);

  Future<void> fetchAllSessions() async {
    if (_isLoading) return;
    if (!connection.isConnected) {
      _isConnected = false;
      _errorMessage = 'اتصل بالراوتر أولاً لعرض الجلسات الحقيقية.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    _isConnected = true;
    notifyListeners();

    try {
      final results = await Future.wait<List<dynamic>>([
        connection.getActivePPPoESessions(),
        connection.getActiveHotspotSessions(),
      ]);

      _pppoeSessions = results[0]
          .whereType<Map>()
          .map((row) => MikrotikSession.fromMap(
                Map<String, dynamic>.from(row),
                isPppoe: true,
              ))
          .where((session) => session.id.isNotEmpty)
          .toList(growable: false);
      _hotspotSessions = results[1]
          .whereType<Map>()
          .map((row) => MikrotikSession.fromMap(
                Map<String, dynamic>.from(row),
                isPppoe: false,
              ))
          .where((session) => session.id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      _errorMessage = 'تعذر جلب الجلسات من الراوتر: ${_safeError(error)}';
      // Keep the last known successful data, but surface the failure explicitly.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> kickSession(MikrotikSession session) async {
    if (!connection.isConnected || session.id.isEmpty) {
      _errorMessage = 'لا يمكن طرد الجلسة دون اتصال ومعرّف RouterOS صالح.';
      notifyListeners();
      return false;
    }

    _errorMessage = '';
    notifyListeners();
    try {
      final success = session.isPppoe
          ? await connection.removeActivePPPoESession(session.id)
          : await connection.removeActiveHotspotSession(session.id);
      if (!success) {
        _errorMessage = 'رفض الراوتر طرد الجلسة أو تعذر تنفيذ الأمر.';
        notifyListeners();
        return false;
      }

      if (session.isPppoe) {
        _pppoeSessions =
            _pppoeSessions.where((item) => item.id != session.id).toList();
      } else {
        _hotspotSessions =
            _hotspotSessions.where((item) => item.id != session.id).toList();
      }
      notifyListeners();
      // Re-read router state so UI is reconciled with the actual device.
      await fetchAllSessions();
      return true;
    } catch (error) {
      _errorMessage = 'فشل طرد الجلسة: ${_safeError(error)}';
      notifyListeners();
      return false;
    }
  }

  String _safeError(Object error) {
    // Avoid displaying request headers or credentials in UI error messages.
    final text = error.toString();
    return text.length > 180 ? text.substring(0, 180) : text;
  }
}
