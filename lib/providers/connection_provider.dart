import 'package:flutter_riverpod/flutter_riverpod.dart';import '../services/mikrotik_service.dart';
final mikrotikProvider=Provider((ref)=>MikrotikService());final connectedProvider=StateProvider<bool>((ref)=>false);final resourceProvider=FutureProvider.autoDispose((ref)=>ref.watch(mikrotikProvider).resource());
