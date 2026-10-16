import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Local, sanitized snapshot metadata for comparing router exports.
///
/// This class does not fetch configuration, encrypt files, or apply changes.
/// Callers must supply data already obtained through an explicitly authorized
/// read operation. Secret-like fields are redacted before persistence/display.
class RouterConfigSnapshot {
  final String id;
  final String routerLabel;
  final DateTime capturedAt;
  final Map<String, dynamic> sanitizedConfig;
  final String sha256;

  RouterConfigSnapshot._({
    required this.id,
    required this.routerLabel,
    required this.capturedAt,
    required this.sanitizedConfig,
    required this.sha256,
  });

  factory RouterConfigSnapshot.capture({
    required String id,
    required String routerLabel,
    required Map<String, dynamic> config,
    DateTime? capturedAt,
  }) {
    final safe = _sanitizeMap(config);
    final canonical = jsonEncode(_sortValue(safe));
    return RouterConfigSnapshot._(
      id: id,
      routerLabel: routerLabel.trim(),
      capturedAt: capturedAt ?? DateTime.now().toUtc(),
      sanitizedConfig: safe,
      sha256: sha256.convert(utf8.encode(canonical)).toString(),
    );
  }

  /// Returns changed leaf paths; values are already sanitized.
  List<RouterConfigChange> diff(RouterConfigSnapshot newer) {
    final before = _flatten(sanitizedConfig);
    final after = _flatten(newer.sanitizedConfig);
    final paths = <String>{...before.keys, ...after.keys}.toList()..sort();
    return paths.where((path) => before[path] != after[path]).map((path) {
      final hadOld = before.containsKey(path);
      final hasNew = after.containsKey(path);
      return RouterConfigChange(
        path: path,
        kind: !hadOld
            ? RouterConfigChangeKind.added
            : !hasNew
                ? RouterConfigChangeKind.removed
                : RouterConfigChangeKind.changed,
        before: before[path],
        after: after[path],
      );
    }).toList(growable: false);
  }

  static const _secretKey = RegExp(
    r'(password|secret|token|private.?key|credential|community|api.?key)',
    caseSensitive: false,
  );

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      result[entry.key] = _secretKey.hasMatch(entry.key)
          ? '[REDACTED]'
          : _sanitizeValue(entry.value);
    }
    return result;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is Map) {
      final map = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        map[key] = _secretKey.hasMatch(key)
            ? '[REDACTED]'
            : _sanitizeValue(entry.value);
      }
      return map;
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    if (value is String) {
      // Avoid leaking secrets embedded in common export assignments.
      return value
          .replaceAllMapped(
            RegExp(
              r'((?:password|secret|token|private-key|api-key)\s*[=:]\s*)("[^"]*"|[^\s,;]+)',
              caseSensitive: false,
            ),
            (match) => '${match[1]}[REDACTED]',
          );
    }
    return value;
  }

  static dynamic _sortValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _sortValue(value[key])};
    }
    if (value is List) return value.map(_sortValue).toList(growable: false);
    return value;
  }

  static Map<String, dynamic> _flatten(
    Map<String, dynamic> source, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        result.addAll(_flatten(value, path));
      } else {
        result[path] = value is List ? jsonEncode(_sortValue(value)) : value;
      }
    }
    return result;
  }
}

enum RouterConfigChangeKind { added, removed, changed }

class RouterConfigChange {
  final String path;
  final RouterConfigChangeKind kind;
  final dynamic before;
  final dynamic after;

  const RouterConfigChange({
    required this.path,
    required this.kind,
    required this.before,
    required this.after,
  });
}
