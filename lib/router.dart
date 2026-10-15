import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';import 'screens/login_screen.dart';import 'widgets/main_shell.dart';
final appRouter=GoRouter(initialLocation:'/',routes:[GoRoute(path:'/',builder:(c,s)=>const SplashScreen()),GoRoute(path:'/login',builder:(c,s)=>const LoginScreen()),GoRoute(path:'/app',builder:(c,s)=>const MainShell())]);
