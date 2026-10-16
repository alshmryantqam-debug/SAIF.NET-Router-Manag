import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/safe_apply_plan.dart';

void main() {
  PlannedRouterChange addUser() => const PlannedRouterChange(
        action: PlannedChangeAction.add,
        resource: '/ip/hotspot/user',
        values: {'name': 'demo', 'password': 'dont-show-this'},
      );

  test('plan requires backup and explicit operator approval', () {
    const plan = SafeApplyPlan(
      title: 'Add test user',
      changes: [
        PlannedRouterChange(
          action: PlannedChangeAction.add,
          resource: '/ip/hotspot/user',
          values: {'name': 'demo'},
        ),
      ],
    );
    final result = plan.validate();
    expect(result.isValid, isFalse);
    expect(result.errors, contains('يلزم تأكيد إنشاء نسخة احتياطية قبل التطبيق'));
    expect(result.errors, contains('يلزم اعتماد المشغّل الصريح قبل التطبيق'));
  });

  test('accepts supported structured plan only when gates are confirmed', () {
    final plan = SafeApplyPlan(
      title: 'Add test user',
      changes: [addUser()],
      backupConfirmed: true,
      operatorApproved: true,
    );
    expect(plan.validate().isValid, isTrue);
  });

  test('rejects arbitrary resource paths', () {
    const plan = SafeApplyPlan(
      title: 'Unsafe',
      changes: [
        PlannedRouterChange(
          action: PlannedChangeAction.set,
          resource: '/system/script/run',
          itemId: '*0',
        ),
      ],
      backupConfirmed: true,
      operatorApproved: true,
    );
    expect(plan.validate().isValid, isFalse);
  });

  test('preview redacts password-like values', () {
    final preview = SafeApplyPlan(
      title: 'Add user',
      changes: [addUser()],
    ).redactedPreview();
    final values = preview.single['values'] as Map<String, String>;
    expect(values['password'], '••••••');
    expect(values['name'], 'demo');
  });
}
