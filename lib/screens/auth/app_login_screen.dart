import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/security/pin_service.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import 'router_login_screen.dart';

class AppLoginScreen extends StatefulWidget {
  const AppLoginScreen({super.key});
  @override
  State<AppLoginScreen> createState() => _AppLoginScreenState();
}
class _AppLoginScreenState extends State<AppLoginScreen> {
  final _pin=TextEditingController(), _confirm=TextEditingController();
  bool _checking=true, _creating=false, _busy=false, _error=false;
  String _message='';
  Duration? _remaining;
  Timer? _timer;

  @override
  void initState(){super.initState(); _init();}
  Future<void> _init() async {
    final set=await PinService.isSet(), left=await PinService.lockRemaining();
    if(!mounted)return;
    setState(()=>{_checking=false,_creating=!set,_remaining=left});
    if(left!=null)_countdown();
  }
  void _countdown(){
    _timer?.cancel();
    _timer=Timer.periodic(const Duration(seconds:1),(_)async{
      final left=await PinService.lockRemaining();
      if(!mounted)return;
      setState(()=>_remaining=left);
      if(left==null)_timer?.cancel();
    });
  }
  void _go()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const RouterLoginScreen()));
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if(_busy||_checking)return;
    final pin=_pin.text;
    if(!RegExp(r'^\d{4,6}$').hasMatch(pin)){setState(()=>{_error=true,_message='أدخل رمزاً من 4 إلى 6 أرقام.'});return;}
    setState(()=>{_busy=true,_error=false,_message=''});
    try{
      if(_creating){
        if(pin!=_confirm.text||!RegExp(r'^\d{4,6}$').hasMatch(_confirm.text)){
          setState(()=>{_error=true,_message='أكد الرمز نفسه باستخدام 4 إلى 6 أرقام.'});return;
        }
        await PinService.setPin(pin);
        if(mounted)_go();
        return;
      }
      final left=await PinService.lockRemaining();
      if(left!=null){setState(()=>_remaining=left);_countdown();return;}
      final result=await PinService.verify(pin);
      if(!mounted)return;
      if(result==PinResult.ok){_go();return;}
      final remaining=await PinService.lockRemaining();
      setState(()=>{_remaining=remaining,_error=true,_message=result==PinResult.locked?'تم قفل الدخول مؤقتاً.':'رمز الوصول غير صحيح.'});
      if(remaining!=null)_countdown();
    }catch(_){if(mounted)setState(()=>{_error=true,_message='تعذر التحقق الآمن من الرمز.'});}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _bio() async {
    if(_busy||_remaining!=null)return;
    setState(()=>_busy=true);
    final ok=await PinService.biometric();
    if(!mounted)return;
    setState(()=>_busy=false);
    if(ok){_go();}else{setState(()=>{_error=true,_message='تعذرت المصادقة بالبصمة. استخدم رمز الوصول.'});}
  }
  @override
  void dispose(){_timer?.cancel();_pin.dispose();_confirm.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppTheme.backgroundColor,
    body:SafeArea(child:Center(child:SingleChildScrollView(
      padding:const EdgeInsets.all(24),child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:460),
        child:GlassCard(useGradient:true,padding:const EdgeInsets.all(24),
          child:_checking?const Center(child:CircularProgressIndicator()):Column(
            mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              const Icon(Icons.shield_moon_rounded,size:76,color:AppTheme.primaryColor),
              const SizedBox(height:16),
              const Text('مرحباً بك في SAIF.NET',textAlign:TextAlign.center,style:TextStyle(fontSize:24,fontWeight:FontWeight.bold,color:AppTheme.textPrimary)),
              const SizedBox(height:8),
              Text(_creating?'أنشئ رمز وصول خاصاً بك':'تسجيل دخول مدير الشبكة',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.textSecondary)),
              const SizedBox(height:22),
              _pinField(_pin,_creating?'رمز جديد (4–6 أرقام)':'رمز الوصول'),
              if(_creating)...[const SizedBox(height:12),_pinField(_confirm,'تأكيد الرمز')],
              if(_remaining!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text('الدخول مقفل مؤقتاً: ${_remaining!.inMinutes}:${(_remaining!.inSeconds%60).toString().padLeft(2,'0')}',textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.dangerColor))),
              if(_error)Padding(padding:const EdgeInsets.only(top:10),child:Text(_message,textAlign:TextAlign.center,style:const TextStyle(color:AppTheme.dangerColor))),
              const SizedBox(height:18),
              ElevatedButton(onPressed:_busy||(_remaining!=null&&!_creating)?null:_submit,style:ElevatedButton.styleFrom(backgroundColor:AppTheme.primaryColor,foregroundColor:Colors.white,padding:const EdgeInsets.all(16)),child:_busy?const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2)):Text(_creating?'حفظ الرمز والمتابعة':'تسجيل الدخول')),
              if(!_creating)...[const SizedBox(height:8),OutlinedButton.icon(onPressed:_busy||_remaining!=null?null:_bio,icon:const Icon(Icons.fingerprint),label:const Text('الدخول بالبصمة'))],
            ]))),
      ))));
  Widget _pinField(TextEditingController c,String label)=>TextField(
    controller:c,obscureText:true,maxLength:6,keyboardType:TextInputType.number,textAlign:TextAlign.center,
    autocorrect:false,enableSuggestions:false,onSubmitted:(_)=>_submit(),
    style:const TextStyle(color:AppTheme.textPrimary),
    decoration:InputDecoration(counterText:'',labelText:label,prefixIcon:const Icon(Icons.lock_outline),filled:true,fillColor:AppTheme.backgroundColor.withOpacity(.5),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none)));
}
