import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/hotspot_user.dart';
import '../providers/connection_provider.dart';
import '../services/business_service.dart';
import '../theme.dart';

final businessRoleProvider=FutureProvider<BusinessRole>((ref)=>BusinessService.instance.getRole());
final billingRecordsProvider=FutureProvider<List<BillingRecord>>((ref)=>BusinessService.instance.invoices());

class BusinessRoleScreen extends ConsumerWidget {
 const BusinessRoleScreen({super.key});
 @override Widget build(BuildContext context,WidgetRef ref){
  final role=ref.watch(businessRoleProvider);
  return Scaffold(backgroundColor:AppColors.bgDeep,appBar:AppBar(title:const Text('الأدوار والصلاحيات')),body:ListView(padding:const EdgeInsets.all(16),children:[
   const _Notice('الأدوار هنا تقيّد واجهة التطبيق على هذا الجهاز فقط. لا تعتبر مصادقة آمنة متعددة المستخدمين قبل إضافة خادم هوية وصلاحيات.'),
   const SizedBox(height:12),
   role.when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>const Text('تعذر تحميل الدور'),data:(current)=>Column(children:BusinessRole.values.map((r)=>Card(color:AppColors.bgCard,child:RadioListTile<BusinessRole>(value:r,groupValue:current,title:Text(r.label),subtitle:Text(switch(r){BusinessRole.manager=>'كل أقسام الإدارة',BusinessRole.distributor=>'الكروت فقط',BusinessRole.technician=>'الأعطال والواجهات والجدار الناري',BusinessRole.customer=>'بوابة المشترك'}),onChanged:(v)async{if(v==null)return;await BusinessService.instance.setRole(v);ref.invalidate(businessRoleProvider);if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تغيير الدور المحلي')));}))).toList()))
  ]));
 }
}

class BillingScreen extends ConsumerStatefulWidget {const BillingScreen({super.key});@override ConsumerState<BillingScreen> createState()=>_BillingScreenState();}
class _BillingScreenState extends ConsumerState<BillingScreen>{
 final amount=TextEditingController(text:'10');DateTime due=DateTime.now().add(const Duration(days:30));bool busy=false;
 @override void dispose(){amount.dispose();super.dispose();}
 void msg(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<void> add()async{
  final users=ref.read(hotspotUsersProvider).valueOrNull??<HotspotUser>[];if(users.isEmpty){msg('لا توجد حسابات Hotspot مقروءة');return;}
  final u=await showDialog<HotspotUser>(context:context,builder:(c)=>SimpleDialog(title:const Text('اختر المشترك'),children:users.take(100).map((x)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,x),child:Text(x.name))).toList()));
  if(u==null)return;final value=double.tryParse(amount.text);if(value==null||value<=0){msg('أدخل مبلغًا صحيحًا');return;}
  final rows=await BusinessService.instance.invoices();rows.add(BillingRecord(id:const Uuid().v4(),username:u.name,amount:value,dueDate:due));await BusinessService.instance.saveInvoices(rows);ref.invalidate(billingRecordsProvider);
 }
 Future<void> paid(BillingRecord record)async{final rows=await BusinessService.instance.invoices();final i=rows.indexWhere((x)=>x.id==record.id);if(i<0)return;rows[i]=rows[i].copyWith(paid:true,paidAt:DateTime.now());await BusinessService.instance.saveInvoices(rows);ref.invalidate(billingRecordsProvider);msg('سُجل الدفع محليًا؛ لم يتم التحقق من بوابة دفع أو تفعيل الراوتر تلقائيًا.');}
 Future<void> disable(BillingRecord record)async{
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تأكيد تعطيل الحساب'),content:Text('تعطيل Hotspot للمستخدم '+record.username+'؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('تعطيل'))]));
  if(ok!=true)return;setState(()=>busy=true);try{final list=await ref.read(mikrotikProvider).hotspotUsers();final u=list.where((x)=>x.name==record.username).firstOrNull;if(u==null||u.id.isEmpty)throw Exception('الحساب غير موجود');await ref.read(mikrotikProvider).setHotspotUserDisabled(u.id,true);ref.invalidate(hotspotUsersProvider);msg('تم تعطيل الحساب يدويًا بعد التأكيد.');}catch(e){msg('تعذر تعطيل الحساب: '+e.toString());}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context){final invoices=ref.watch(billingRecordsProvider);return Scaffold(backgroundColor:AppColors.bgDeep,appBar:AppBar(title:const Text('الفوترة والتحصيل')),body:ListView(padding:const EdgeInsets.all(16),children:[
  const _Notice('سجل الفواتير محلي على الهاتف. لا توجد بوابة دفع أو خدمة خلفية حاليًا؛ لذلك لا يوجد تعطيل تلقائي عند إغلاق التطبيق. تحقّق من الدفع قبل تعطيل أي مشترك.'),
  const SizedBox(height:10),TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'قيمة الفاتورة')),
  ListTile(title:const Text('تاريخ الاستحقاق'),subtitle:Text(due.toLocal().toString().split(' ').first),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:context,initialDate:due,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:3650)));if(d!=null)setState(()=>due=d);}),
  FilledButton.icon(onPressed:add,icon:const Icon(Icons.add_card),label:const Text('إنشاء فاتورة')),
  const SizedBox(height:14),
  invoices.when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>const Text('تعذر تحميل الفواتير'),data:(list)=>Column(children:[
   Row(children:[Expanded(child:_Stat('الفواتير',list.length.toString())),const SizedBox(width:8),Expanded(child:_Stat('متأخرة',list.where((x)=>x.overdue).length.toString()))]),
   ...list.reversed.map((x)=>Card(color:AppColors.bgCard,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(x.username,style:const TextStyle(fontWeight:FontWeight.bold))),Text(x.paid?'مدفوعة':x.overdue?'متأخرة':'مستحقة',style:TextStyle(color:x.paid?AppColors.success:x.overdue?AppColors.danger:AppColors.warning))]),
    const SizedBox(height:5),Text('المبلغ: '+x.amount.toStringAsFixed(2)+' · الاستحقاق: '+x.dueDate.toLocal().toString().split(' ').first),
    if(!x.paid)Wrap(spacing:8,children:[TextButton(onPressed:()=>paid(x),child:const Text('تسجيل الدفع')),if(x.overdue)FilledButton.tonal(onPressed:busy?null:()=>disable(x),child:const Text('تعطيل يدوي بعد التأكيد'))])
   ]))))
  ]))
 ]));}
}

class CustomerPortalScreen extends ConsumerWidget {
 const CustomerPortalScreen({super.key});
 @override Widget build(BuildContext context,WidgetRef ref){
  final active=ref.watch(hotspotActiveProvider).valueOrNull??<Map<String,String>>[];
  final users=ref.watch(hotspotUsersProvider).valueOrNull??<HotspotUser>[];
  final invoices=ref.watch(billingRecordsProvider).valueOrNull??<BillingRecord>[];
  final session=active.where((x)=>(x['user']??'').isNotEmpty).firstOrNull;
  final name=session?['user']??'';
  final user=users.where((x)=>x.name==name).firstOrNull;
  final rx=int.tryParse(session?['bytes-in']??session?['bytesIn']??'0')??0;
  final tx=int.tryParse(session?['bytes-out']??session?['bytesOut']??'0')??0;
  final rows=invoices.where((x)=>x.username==name).toList();
  final due=rows.where((x)=>!x.paid).fold<double>(0,(s,x)=>s+x.amount);
  return Scaffold(backgroundColor:AppColors.bgDeep,appBar:AppBar(title:const Text('بوابة المشترك')),body:ListView(padding:const EdgeInsets.all(16),children:[
   const _Notice('نسخة أولية تعرض جلسة Hotspot النشطة الأولى على الراوتر المتصل. بوابة عميل مستقلة تحتاج تسجيل دخول آمنًا لكل مشترك وخادمًا يفصل بياناته عن حساب الإدارة.'),
   const SizedBox(height:12),
   if(name.isEmpty)const _Notice('لا توجد جلسة Hotspot نشطة للعرض.')
   else ...[_Stat('اسم المستخدم',name),const SizedBox(height:8),Row(children:[Expanded(child:_Stat('التنزيل',_bytes(rx))),const SizedBox(width:8),Expanded(child:_Stat('الرفع',_bytes(tx)))]),const SizedBox(height:8),_Stat('الرصيد المستحق',due.toStringAsFixed(2)),if(user!=null)Padding(padding:const EdgeInsets.only(top:8),child:_Stat('حد البيانات',user.limitBytesTotal>0?_bytes(user.limitBytesTotal):'غير محدد'))]
  ]));
 }
}

class _Notice extends StatelessWidget{const _Notice(this.text);final String text;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.primary.withOpacity(.08),borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.primary.withOpacity(.25))),child:Text(text,style:const TextStyle(color:AppColors.textSecondary,fontSize:12,height:1.5)));}
class _Stat extends StatelessWidget{const _Stat(this.label,this.value);final String label,value;@override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:AppColors.bgCard,borderRadius:BorderRadius.circular(16),border:Border.all(color:AppColors.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:AppColors.textMuted,fontSize:11)),const SizedBox(height:5),Text(value,style:const TextStyle(color:AppColors.textPrimary,fontSize:15,fontWeight:FontWeight.w900),maxLines:2,overflow:TextOverflow.ellipsis)]));}
String _bytes(int b){if(b<=0)return '0 B';const u=['B','KB','MB','GB','TB'];var n=b.toDouble();var i=0;while(n>=1024&&i<u.length-1){n/=1024;i++;}return n.toStringAsFixed(i==0?0:1)+' '+u[i];}

class BusinessGate extends ConsumerWidget {
 const BusinessGate({super.key,required this.allowed,required this.child});
 final List<BusinessRole> allowed; final Widget child;
 @override Widget build(BuildContext context,WidgetRef ref){
  final role=ref.watch(businessRoleProvider);
  return role.when(loading:()=>const Scaffold(body:Center(child:CircularProgressIndicator())),error:(_,__)=>const Scaffold(body:Center(child:Text('تعذر التحقق من الدور'))),data:(r)=>allowed.contains(r)?child:Scaffold(backgroundColor:AppColors.bgDeep,appBar:AppBar(title:const Text('صلاحيات الوصول')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,color:AppColors.warning,size:48),const SizedBox(height:12),const Text('هذا القسم غير متاح للدور الحالي',style:TextStyle(color:AppColors.textPrimary,fontWeight:FontWeight.bold)),const SizedBox(height:12),FilledButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const BusinessRoleScreen())),child:const Text('إدارة الدور المحلي'))]))));
 }
}
