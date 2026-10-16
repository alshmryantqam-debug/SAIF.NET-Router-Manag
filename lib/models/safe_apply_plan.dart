/// A preview-only plan for proposed RouterOS configuration changes.
///
/// This model intentionally does not execute commands. Applying a plan must be
/// implemented behind a separate backup, validation, approval and audit flow.
enum PlannedChangeAction { add, set, remove }

class PlannedRouterChange {
  final PlannedChangeAction action;
  final String resource;
  final String? itemId;
  final Map<String, String> values;

  const PlannedRouterChange({
    required this.action,
    required this.resource,
    this.itemId,
    this.values = const {},
  });

  Map<String, Object?> toJson() => {
        'action': action.name,
        'resource': resource,
        if (itemId != null) 'itemId': itemId,
        'values': Map<String, String>.from(values),
      };
}

class SafeApplyValidation {
  final List<String> errors;
  const SafeApplyValidation(this.errors);

  bool get isValid => errors.isEmpty;
}

/// Conservative validation for the initial preview workflow.
///
/// Only explicitly supported resource paths are accepted. Raw RouterOS
/// scripts/commands are not represented by this type and must never be passed
/// through this validator as if they were structured changes.
class SafeApplyPlan {
  static const supportedResources = <String>{
    '/ip/hotspot/user',
    '/ip/hotspot/user/profile',
    '/ppp/secret',
    '/queue/simple',
    '/ip/firewall/filter',
    '/ip/firewall/mangle',
    '/ip/firewall/nat',
  };

  final String title;
  final List<PlannedRouterChange> changes;
  final bool backupConfirmed;
  final bool operatorApproved;

  const SafeApplyPlan({
    required this.title,
    required this.changes,
    this.backupConfirmed = false,
    this.operatorApproved = false,
  });

  SafeApplyValidation validate() {
    final errors = <String>[];
    if (title.trim().isEmpty) errors.add('اكتب وصفاً للتغيير');
    if (changes.isEmpty) errors.add('الخطة لا تحتوي على تغييرات');

    for (var i = 0; i < changes.length; i++) {
      final change = changes[i];
      final prefix = 'التغيير ${i + 1}: ';
      if (!supportedResources.contains(change.resource)) {
        errors.add('${prefix}المسار غير مدعوم');
      }
      if (change.action == PlannedChangeAction.add && change.itemId != null) {
        errors.add('${prefix}عملية الإضافة لا تحتاج إلى itemId');
      }
      if (change.action != PlannedChangeAction.add &&
          (change.itemId == null || change.itemId!.trim().isEmpty)) {
        errors.add('${prefix}يلزم تحديد معرّف العنصر');
      }
      if (change.values.keys.any((key) =>
          key.trim().isEmpty ||
          key.startsWith('.') ||
          key.contains('/') ||
          key.contains('\n') ||
          key.contains('\r'))) {
        errors.add('${prefix}يوجد اسم حقل غير صالح');
      }
      if (change.values.values.any(
          (value) => value.contains('\u0000'))) {
        errors.add('${prefix}القيمة تحتوي على محرف غير صالح');
      }
      if (change.action == PlannedChangeAction.remove &&
          change.values.isNotEmpty) {
        errors.add('${prefix}الحذف لا يقبل حقولاً إضافية');
      }
    }

    if (!backupConfirmed) {
      errors.add('يلزم تأكيد إنشاء نسخة احتياطية قبل التطبيق');
    }
    if (!operatorApproved) {
      errors.add('يلزم اعتماد المشغّل الصريح قبل التطبيق');
    }
    return SafeApplyValidation(List.unmodifiable(errors));
  }

  /// Redacted human-readable preview. Secret-like field values are never shown.
  List<Map<String, Object?>> redactedPreview() => changes.map((change) {
        final values = <String, String>{};
        for (final entry in change.values.entries) {
          final key = entry.key.toLowerCase();
          final secret = key.contains('password') ||
              key.contains('secret') ||
              key.contains('token') ||
              key.contains('private-key');
          values[entry.key] = secret ? '••••••' : entry.value;
        }
        return {
          'action': change.action.name,
          'resource': change.resource,
          if (change.itemId != null) 'itemId': change.itemId,
          'values': values,
        };
      }).toList(growable: false);
}
