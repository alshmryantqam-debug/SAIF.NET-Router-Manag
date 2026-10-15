import 'package:flutter_riverpod/flutter_riverpod.dart';import '../services/storage_service.dart';import '../models/router_config.dart';
final storageProvider=Provider((ref)=>StorageService());final savedRouterProvider=FutureProvider<RouterConfigModel?>((ref)=>ref.watch(storageProvider).load());
