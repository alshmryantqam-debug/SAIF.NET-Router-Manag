import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum BusinessRole { manager, distributor, technician, customer }

extension BusinessRoleX on BusinessRole {
  String get label => switch (this) {
        BusinessRole.manager => 'مدير',
        BusinessRole.distributor => 'موزع',
        BusinessRole.technician => 'فني',
        BusinessRole.customer => 'مشترك',
      };
}

class BillingRecord {
  const BillingRecord({
    required this.id,
    required this.username,
    required this.amount,
    required this.dueDate,
    this.paid = false,
    this.paidAt,
  });

  final String id;
  final String username;
  final double amount;
  final DateTime dueDate;
  final bool paid;
  final DateTime? paidAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'paid': paid,
        'paidAt': paidAt?.toIso8601String(),
      };

  factory BillingRecord.fromJson(Map<String, dynamic> json) => BillingRecord(
        id: json['id'] as String,
        username: json['username'] as String,
        amount: (json['amount'] as num).toDouble(),
        dueDate: DateTime.parse(json['dueDate'] as String),
        paid: json['paid'] == true,
        paidAt: json['paidAt'] == null
            ? null
            : DateTime.parse(json['paidAt'] as String),
      );

  BillingRecord copyWith({bool? paid, DateTime? paidAt}) => BillingRecord(
        id: id,
        username: username,
        amount: amount,
        dueDate: dueDate,
        paid: paid ?? this.paid,
        paidAt: paidAt ?? this.paidAt,
      );

  bool get overdue => !paid && dueDate.isBefore(DateTime.now());
}

class BusinessService {
  BusinessService._();

  static final instance = BusinessService._();
  static const _roleKey = 'tikplus.business.role';
  static const _billingKey = 'tikplus.business.billing.v1';

  Future<BusinessRole> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_roleKey);
    return BusinessRole.values.where((role) => role.name == value).firstOrNull ??
        BusinessRole.manager;
  }

  Future<void> setRole(BusinessRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
  }

  Future<List<BillingRecord>> invoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_billingKey);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => BillingRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveInvoices(List<BillingRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _billingKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}
