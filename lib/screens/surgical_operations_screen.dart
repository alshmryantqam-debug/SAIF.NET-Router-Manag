import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/surgical_provider.dart';

class SurgicalOperationsScreen extends StatefulWidget {
  const SurgicalOperationsScreen({super.key});
  @override
  State<SurgicalOperationsScreen> createState() => _SurgicalOperationsScreenState();
}

class _SurgicalOperationsScreenState extends State<SurgicalOperationsScreen> with SingleTickerProviderStateMixin {
  final _targetController = TextEditingController();
  late final AnimationController _radar;
  bool _isPppoe = true;
  String? _selectedProfile;

  @override
  void initState() { super.initState(); _radar = AnimationController(vsync:this, duration:const Duration(seconds:4))..repeat(); }
  @override
  void dispose() { _targetController.dispose(); _radar.dispose(); super.dispose(); }

  Future<bool> _confirm(String title, String message) async => await showDialog<bool>(
    context:context, builder:(context) => AlertDialog(
      title:Text(title), content:Text(message),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('تأكيد التنفيذ'))],
    )) ?? false;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(
      backgroundColor:const Color(0xFF100B1C),
      appBar:AppBar(title:const Text('غرفة العمليات'),centerTitle:true,backgroundColor:const Color(0xFF1C142B)),
      body:Consumer<SurgicalProvider>(builder:(context,p,_)=>ListView(
        padding:const EdgeInsets.all(16), children:[
          Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFF1C142B),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFF7B2CFF))),
            child:Column(children:[
              TextField(controller:_targetController,style:const TextStyle(color:Colors.white),decoration:const InputDecoration(labelText:'اسم المشترك',labelStyle:TextStyle(color:Colors.white70),prefixIcon:Icon(Icons.person_search,color:Color(0xFF00E5FF)))),
              const SizedBox(height:12),
              SegmentedButton<bool>(segments:const [ButtonSegment(value:true,label:Text('برودباند')),ButtonSegment(value:false,label:Text('نقطة اتصال'))],selected:{_isPppoe},onSelectionChanged:p.isProcessing?null:(s)=>setState(()=>_isPppoe=s.first)),
              const SizedBox(height:12),
              SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:p.isProcessing?null:()=>p.loadTarget(_targetController.text,_isPppoe),icon:const Icon(Icons.radar),label:const Text('البحث عن المشترك'))),
            ])),
          const SizedBox(height:16),
          Container(height:190,decoration:BoxDecoration(color:Colors.black26,borderRadius:BorderRadius.circular(18),border:Border.all(color:p.target==null?const Color(0xFF00E5FF):const Color(0xFF4CAE7D),width:1.5)),
            child:Stack(alignment:Alignment.center,children:[
              RotationTransition(turns:_radar,child:Icon(Icons.radar,size:155,color:(p.target==null?const Color(0xFF00E5FF):const Color(0xFF4CAE7D)).withOpacity(.13))),
              if(p.isProcessing) const CircularProgressIndicator(color:Color(0xFFE040FB))
              else if(p.target==null) const Text('بانتظار تحديد المشترك',style:TextStyle(color:Colors.white60))
              else Column(mainAxisSize:MainAxisSize.min,children:[
                const Icon(Icons.gps_fixed,color:Color(0xFF4CAE7D),size:32),
                Text(p.target!.name,style:const TextStyle(color:Color(0xFF4CAE7D),fontWeight:FontWeight.w900,fontSize:18)),
                Text('الباقة الحالية: ${p.target!.profile}',style:const TextStyle(color:Colors.white)),
                Text(p.target!.activeMac==null?'لا توجد جلسة نشطة':'الجهاز المتصل: ${p.target!.activeMac}',style:const TextStyle(color:Colors.white70,fontSize:12)),
              ]),
            ])),
          const SizedBox(height:12),
          Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.black45,borderRadius:BorderRadius.circular(10)),child:Text(p.operationLog,style:const TextStyle(color:Color(0xFFE5C158),fontWeight:FontWeight.bold))),
          if(p.target!=null)...[
            const SizedBox(height:18),
            Card(color:const Color(0xFF1C142B),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('تقييد الحساب على الجهاز الحالي',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
              const SizedBox(height:8),
              Text(p.target!.callerId==null?'الحساب غير مقيّد بعنوان جهاز.':'العنوان المقيّد: ${p.target!.callerId}',style:const TextStyle(color:Colors.white70)),
              const SizedBox(height:12),
              SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:p.isProcessing||p.target!.activeMac==null?null:()async{if(await _confirm('تأكيد تقييد الجهاز','سيُقيّد هذا الحساب على عنوان الجهاز المرصود، وقد يمنع أجهزة أخرى من الدخول.')){if(context.mounted) await p.lockMacAddress();}},icon:const Icon(Icons.lock),label:const Text('تقييد الحساب على هذا الجهاز'))),
            ]))),
            const SizedBox(height:12),
            Card(color:const Color(0xFF1C142B),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('تغيير الباقة وتطبيقها فوراً',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
              const SizedBox(height:8),
              DropdownButtonFormField<String>(value:p.profiles.contains(_selectedProfile)?_selectedProfile:null,dropdownColor:const Color(0xFF1C142B),decoration:const InputDecoration(labelText:'اختر الباقة',labelStyle:TextStyle(color:Colors.white70)),items:p.profiles.map((x)=>DropdownMenuItem(value:x,child:Text(x,style:const TextStyle(color:Colors.white)))).toList(),onChanged:p.isProcessing?null:(v)=>setState(()=>_selectedProfile=v)),
              const SizedBox(height:12),
              SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:p.isProcessing||_selectedProfile==null?null:()async{if(await _confirm('تأكيد تغيير الباقة','سيتم تغيير الباقة ثم فصل الجلسة النشطة إن وُجدت. قد ينقطع اتصال المشترك مؤقتاً.')){if(context.mounted) await p.atomicProfileShift(_selectedProfile!);}},icon:const Icon(Icons.bolt),label:const Text('تغيير الباقة وفصل الجلسة'))),
            ]))),
          ],
        ])),
    ));
}
