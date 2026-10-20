import '../api/router_client.dart';

class ExpiryGuard {
  /// RouterOS dates may be ISO (2026-10-20) or month/day/year (oct/20/2026).
  /// Detect the router's format using its clock.
  static String _fmt(DateTime d, String sample) {
    String two(int v) => v.toString().padLeft(2, '0');
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(sample)) {
      return '${d.year}-${two(d.month)}-${two(d.day)}';
    }
    const m = ['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];
    return '${m[d.month - 1]}/${two(d.day)}/${d.year}';
  }

  static bool _safe(String user) =>
      !user.contains('"') && !user.contains(r'\') && !user.contains(r'$');

  /// Schedule disabling the PPP secret and removing its active session at 23:59.
  static Future<void> schedule(
    RouterOsClient c,
    String user,
    DateTime expiry,
  ) async {
    if (!_safe(user) || user.isEmpty) return;
    final dynamic clockResponse = await c.get('/system/clock');
    if (clockResponse is! Map || clockResponse['date'] == null) {
      throw StateError('تعذر قراءة تاريخ الراوتر من system/clock');
    }
    final date = _fmt(expiry, clockResponse['date'].toString());
    final name = 'nova-exp-$user';

    await cancel(c, user);
    await c.put('/system/scheduler', {
      'name': name,
      'start-date': date,
      'start-time': '23:59:00',
      'interval': '0s',
      'comment': 'nova-expiry',
      'on-event': '/ppp secret disable [find name="$user"]; '
          '/ppp active remove [find name="$user"]; '
          '/system scheduler remove [find name="$name"]',
    });
  }

  static Future<void> cancel(RouterOsClient c, String user) async {
    if (!_safe(user) || user.isEmpty) return;
    try {
      await c.delete('/system/scheduler/nova-exp-$user');
    } catch (_) {
      // No matching scheduler (or the client cannot delete by this path).
    }
  }
}
