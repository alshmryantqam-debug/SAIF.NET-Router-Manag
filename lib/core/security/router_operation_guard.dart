/// Safety gate for future RouterOS write operations.
///
/// Read operations do not need this guard. Configuration changes must have
/// explicit approval, a verified backup, and a rollback plan.
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
