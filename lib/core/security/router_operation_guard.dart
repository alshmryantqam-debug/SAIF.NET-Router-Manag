/// Safety gate for future RouterOS write operations.
///
/// Read operations should not call this guard. Any configuration-changing
/// operation must require explicit user confirmation and a recovery plan.
class RouterOperationGuard {
  const RouterOperationGuard._();

  static void requireWriteApproval({
    required bool explicitlyConfirmed,
    required bool backupVerified,
    required bool rollbackPlanAvailable,
  }) {
    if (!explicitlyConfirmed) {
      throw StateError('تحتاج العملية إلى موافقة صريحة من المستخدم.');
    }
    if (!backupVerified) {
      throw StateError('لا يمكن المتابعة قبل التحقق من النسخة الاحتياطية.');
    }
    if (!rollbackPlanAvailable) {
      throw StateError('لا يمكن المتابعة دون خطة تراجع واضحة.');
    }
  }
}
