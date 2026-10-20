import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../core/api/connection_diagnostics.dart';
import '../../providers/connection_provider.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import '../app_shell.dart';

class RouterLoginScreen extends StatefulWidget {
  const RouterLoginScreen({super.key});
  @override
  State<RouterLoginScreen> createState()=>_RouterLoginScreenState();
}
class _RouterLoginScreenState extends State<RouterLoginScreen>{
  static const _storage=FlutterSecureStorage();
  final _ip=TextEditingController(),_port=TextEditingController(),_user=TextEditingController(),_pass=TextEditingController();
  bool _remember=false,_loading=false;
  List<DiagStep> _steps=[];
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{
    final v=await Future.wait([_storage.read(key:'router_ip'),_storage.read(key:'router_username'),_storage.read(key:'router_password')]);
    if(!mounted)return;
    setState(()=>{_ip.text=v[0]??'',_user.text=v[1]??'',if(v[2]!=null)_pass.text=v[2]!,_remember=v[2]!=null});
  }
  Future<void> _connect()async{
    FocusScope.of(context).unfocus();
    final host=_ip.text.trim(),user=_user.text.trim(),pass=_pass.text,portText=_port.text.trim();
    final port=portText.isEmpty?null:int.tryParse(portText);
    if(host.isEmpty||user.isEmpty||pass.isEmpty||(portText.isNotEmpty&&(port==null||port<1||port>65535))){
      setState(()=>_steps=[const DiagStep('البيانات المطلوبة',false,'أدخل عنوان الراوتر واسم المستخدم وكلمة المرور ومنفذاً صحيحاً إن حددته.')]);return;
    }
    setState(()=>{_loading=true,_steps=[]});
    try{
      final result=await ConnectionDiagnostics.run(host:host,user:user,pass:pass,customPort:port);
      if(!mounted){result.client?.close();return;}
      setState(()=>_steps=result.steps);
      final client=result.client;
      if(!result.success||client==null)return;
      final provider=context.read<ConnectionProvider>();
      await provider.useClient(client:client,host:host,username:user,password:pass,https:client.https,port:client.port);
      await _storage.write(key:'router_ip',value:host);
      await _storage.write(key:'router_username',value:user);
      if(_remember){await _storage.write(key:'router_password',value:pass);}else{await _storage.delete(key:'router_password');}
      if(!mounted)return;
      if(provider.isConnected){Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const AppShell()));}
      else{setState(()=>_steps=[..._steps,DiagStep('تحميل بيانات الراوتر',false,provider.errorMessage)]);}
    }catch(e){if(mounted)setState(()=>_steps=[..._steps,DiagStep('الاتصال',false,'تعذر إكمال الاتصال: $e')]);}
    finally{if(mounted)setState(()=>_loading=false);}
  }
  @override
  void dispose(){_ip.dispose();_port.dispose();_user.dispose();_pass.dispose();super.dispose();}
  Widget _field(TextEditingController c,String label,IconData icon,{bool secret=false,TextInputType keyboard=TextInputType.text})=>Padding(
    padding:const EdgeInsets.only(bottom:12),child:TextField(controller:c,obscureText:secret,keyboardType:keyboard,style:const TextStyle(color:AppTheme.textPrimary),
      decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon,color:AppTheme.primaryColor),filled:true,fillColor:AppTheme.backgroundColor.withOpacity(.55),border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none))));
  @override
  Widget build(BuildContext context){
    final provider=context.watch<ConnectionProvider>();
    return Scaffold(backgroundColor:AppTheme.backgroundColor,body:SafeArea(child:Center(child:SingleChildScrollView(
      padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:Column(children:[
        const Icon(Icons.router_outlined,size:64,color:AppTheme.primaryColor),const SizedBox(height:16),
        const Text('الاتصال بالراوتر',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold,color:AppTheme.textPrimary)),
        const SizedBox(height:8),const Text('تشخيص الاتصال عبر RouterOS REST',style:TextStyle(color:AppTheme.textSecondary)),const SizedBox(height:22),
        GlassCard(padding:const EdgeInsets.all(20),child:Column(children:[
          _field(_ip,'عنوان IP أو اسم المضيف',Icons.wifi,keyboard:TextInputType.url),
          _field(_port,'المنفذ (اختياري)',Icons.numbers,keyboard:TextInputType.number),
          _field(_user,'اسم المستخدم',Icons.person_outline),
          _field(_pass,'كلمة المرور',Icons.lock_outline,secret:true),
          CheckboxListTile(value:_remember,onChanged:(v)=>setState(()=>_remember=v??false),contentPadding:EdgeInsets.zero,activeColor:AppTheme.primaryColor,
            title:const Text('تذكّر الراوتر',style:TextStyle(color:AppTheme.textPrimary)),
            subtitle:const Text('كلمة المرور تُحفظ في التخزين الآمن فقط عند التفعيل',style:TextStyle(color:AppTheme.textSecondary,fontSize:12))),
          SizedBox(width:double.infinity,height:52,child:ElevatedButton(onPressed:_loading||provider.isLoading?null:_connect,style:ElevatedButton.styleFrom(backgroundColor:AppTheme.primaryColor,foregroundColor:Colors.white),
            child:_loading?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Text('تشخيص واتصال')))
        ])),
        if(_steps.isNotEmpty)...[const SizedBox(height:16),GlassCard(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('نتائج التشخيص',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:AppTheme.textPrimary)),const SizedBox(height:12),
          for(final s in _steps)Padding(padding:const EdgeInsets.only(bottom:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(s.ok?Icons.check_circle:Icons.cancel,color:s.ok?AppTheme.successColor:AppTheme.dangerColor,size:22),const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(s.title,style:const TextStyle(fontWeight:FontWeight.w600,color:AppTheme.textPrimary)),
              const SizedBox(height:3),Text(s.detail,style:const TextStyle(color:AppTheme.textSecondary))
            ]))
          ]))
        ]))]
      ]))))));
  }
}
