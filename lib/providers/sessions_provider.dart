import 'package:flutter/foundation.dart';

import '../models/mikrotik_session_model.dart';
import 'connection_provider.dart';

class SessionsProvider extends ChangeNotifier {
  final ConnectionProvider connection;

  SessionsProvider(this.connection);

  bool _isLoading = false;
  bool _isConnected = false;
  final Set<String> _sessionsBeingDisconnected = <String>{};
  String _errorMessage = '';
  List<MikrotikSession> _pppoeSessions = const [];
  List<MikrotikSession> _hotspotSessions = const [];

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get errorMessage => _errorMessage;
  List<MikrotikSession> get pppoeSessions => List.unmodifiable(_pppoeSessions);
  List<MikrotikSession> get hotspotSessions => List.unmodifiable(_hotspotSessions);

  Future<void> fetchAllSessions() => _fetchSessions();

  Future<void> _fetchSessions({bool force = false}) async {
    if (_isLoading && !force) return;
    if (_isLoading && force) {
      // The currently running request may have captured the pre-disconnect
      // state, so wait for it to finish before taking a fresh snapshot.
      while (_isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
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
      _pppoeSessions = const [];
      _hotspotSessions = const [];
      _isConnected = false;
      _errorMessage = 'تعذر جلب الجلسات من الراوتر: ${_safeError(error)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> kickSession(MikrotikSession session) async {
    final key = '${session.isPppoe ? 'pppoe' : 'hotspot'}:${session.id}';
    if (!connection.isConnected || session.id.trim().isEmpty) {
      _errorMessage = 'لا يمكن فصل الجلسة دون اتصال ومعرّف صالح من الراوتر.';
      notifyListeners();
      return false;
    }
    if (!_sessionsBeingDisconnected.add(key)) {
      _errorMessage = 'يجري تنفيذ طلب فصل هذه الجلسة بالفعل.';
      notifyListeners();
      return false;
    }

    _errorMessage = '';
    notifyListeners();
    try {
      // Do not remove the row optimistically: wait for RouterOS to accept the
      // command, then reconcile with a fresh read from the device.
      if (session.isPppoe) {
        await connection.removeActivePPPoESession(session.id);
      } else {
        await connection.removeActiveHotspotSession(session.id);
      }

      // Re-read both live tables. A failed refresh is not reported as a
      // verified success because the router state could not be confirmed.
      await _fetchSessions(force: true);
      if (_errorMessage.isNotEmpty) return false;

      final stillActive = session.isPppoe
          ? _pppoeSessions.any((item) => item.id == session.id)
          : _hotspotSessions.any((item) => item.id == session.id);
      if (stillActive) {
        _errorMessage = 'قبل الراوتر الطلب لكن الجلسة ما زالت ظاهرة؛ حدّث القائمة وتحقق من الراوتر.';
        notifyListeners();
        return false;
      }
      return true;
    } catch (error) {
      _errorMessage = 'تعذر فصل الجلسة: ${_safeError(error)}';
      notifyListeners();
      return false;
    } finally {
      _sessionsBeingDisconnected.remove(key);
      notifyListeners();
    }
  }

  String _safeError(Object error) {
    // Avoid displaying request headers or credentials in UI error messages.
    final text = error.toString();
    return text.length > 180 ? text.substring(0, 180) : text;
  }
}
