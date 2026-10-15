import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';
class TikPlusApp extends StatelessWidget {
 const TikPlusApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp.router(title:'TikPlus ULTRA',debugShowCheckedModeBanner:false,theme:AppTheme.dark,routerConfig:appRouter);
}
