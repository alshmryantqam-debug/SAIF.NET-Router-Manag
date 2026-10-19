import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/core/security/router_operation_guard.dart';

void main() {
  group('RouterOperationGuard', () {
    test('rejects a write without explicit confirmation', () {
      expect(
        () => RouterOperationGuard.requireWriteApproval(
          explicitlyConfirmed: false,
          backupVerified: true,
          rollbackPlanAvailable: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a write without a verified backup', () {
      expect(
        () => RouterOperationGuard.requireWriteApproval(
          explicitlyConfirmed: true,
          backupVerified: false,
          rollbackPlanAvailable: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a write without a rollback plan', () {
      expect(
        () => RouterOperationGuard.requireWriteApproval(
          explicitlyConfirmed: true,
          backupVerified: true,
          rollbackPlanAvailable: false,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows writes only when all safety conditions pass', () {
      expect(
        () => RouterOperationGuard.requireWriteApproval(
          explicitlyConfirmed: true,
          backupVerified: true,
          rollbackPlanAvailable: true,
        ),
        returnsNormally,
      );
    });
  });
}
