import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum BusinessRole { manager, distributor, technician, customer }
extension BusinessRoleX on BusinessRole {
  String get label => switch(this) { BusinessRole.manager=>'مدير', BusinessRole.distributor=>'موزع', BusinessRole.technician=>'فني', BusinessRole.customer=>'مشترك' };
}
class BillingRecord {
  const BillingRecord({required this.id,required this.username,required this.amount,required this.dueDate,this.paid=false,this.paidAt});
  final String id,username; final double amount; final DateTime dueDate; final bool paid; final DateTime? paidAt;
  Map<String,dynamic> toJson()=>{'id':id,'username':username,'amount':amount,'dueDate':dueDate.toIso8601String(),'paid':paid,'paidAt':paidAt?.toIso8601String()};
  factory BillingRecord.fromJson(Map<String,dynamic> j)=>BillingRecord(id:j['id'] as String,username:j['username'] as String,amount:(j['amount'] as num).toDouble(),dueDate:DateTime.parse(j['dueDate'] as String),paid:j['paid']==true,paidAt:j['paidAt']==null?null:DateTime.parse(j['paidAt'] as String));
  BillingRecord copyWith({bool? paid,DateTime? paidAt})=>BillingRecord(id:id,username:username,amount:amount,dueDate:dueDate,paid:paid??this.paid,paidAt:paidAt??this.paidAt);
  bool get overdue=>!paid&&dueDate.isBefore(DateTime.now());
}
class BusinessService {
  BusinessService._(); static final instance=BusinessService._();
  static const storage=FlutterSecureStorage(aOptions:AndroidOptions(encryptedSharedPreferences:true));
  Future<BusinessRole> getRole() async {final v=await storage.read(key:'tikplus.business.role');return BusinessRole.values.where((r)=>r.name==v).firstOrNull??BusinessRole.manager;}
  Future<void> setRole(BusinessRole r)=>storage.write(key:'tikplus.business.role',value:r.name);
  Future<List<BillingRecord>> invoices() async {try{final s=await storage.read(key:'tikplus.business.billing.v1');if(s==null)return [];final j=jsonDecode(s);if(j is! List)return [];return j.whereType<Map>().map((e)=>BillingRecord.fromJson(Map<String,dynamic>.from(e))).toList();}catch(_){return [];}}
  Future<void> saveInvoices(List<BillingRecord> r)=>storage.write(key:'tikplus.business.billing.v1',value:jsonEncode(r.map((x)=>x.toJson()).toList()));
}