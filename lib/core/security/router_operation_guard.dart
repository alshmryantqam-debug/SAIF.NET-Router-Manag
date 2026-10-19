class RouterOperationGuard {
  static const List<String> _readOnlySuffixes = [
    '/print',
    '/getall',
    '/monitor',
    '/monitor-traffic',
    '/registration-table/print',
    '/active/print',
    '/resource/print',
    '/identity/print',
    '/health/print',
  ];

  static const List<String> _WriteOrDestructiveKeywords = [
    '/add',
    '/set',
    '/remove',
    '/disable',
    '/enable',
    '/reset-configuration',
    '/reboot',
    '/shutdown',
  ];

  /// يفحص ما إذا كان مسار الأمر في RouterOS للقراءة فقط وآمن للتنفيذ التلقائي
  static bool isReadOnlyCommandPath(String path) {
    final normalized = path.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    for (final keyword in _WriteOrDestructiveKeywords) {
      if (normalized.endsWith(keyword) || normalized.contains('$keyword ')) {
        return false;
      }
    }

    for (final suffix in _readOnlySuffixes) {
      if (normalized.endsWith(suffix)) {
        return true;
      }
    }

    // أوامر REST API التي تبدأ بـ GET أو مسارات موارد عامة بدون تعديل
    return !normalized.contains('=') && !normalized.endsWith('/remove');
  }
}
