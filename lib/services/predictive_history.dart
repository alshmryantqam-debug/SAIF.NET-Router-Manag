import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PredictiveSample {
  const PredictiveSample({required this.time, required this.cpu, required this.ram});
  final DateTime time;
  final double cpu;
  final double ram;
  Map<String,dynamic> toJson()=>{'time':time.toIso8601String(),'cpu':cpu,'ram':ram};
  factory PredictiveSample.fromJson(Map<String,dynamic> j)=>PredictiveSample(time:DateTime.parse(j['time'] as String),cpu:(j['cpu'] as num).toDouble(),ram:(j['ram'] as num).toDouble());
}

class PredictiveHistory {
  PredictiveHistory._();
  static const FlutterSecureStorage _storage=FlutterSecureStorage();
  static const String _key='tikplus.resource.history.v1';

  static Future<List<PredictiveSample>> load() async {
    final raw=await _storage.read(key:_key);
    if(raw==null)return [];
    try {
      final now=DateTime.now();
      return (jsonDecode(raw) as List).map((e)=>PredictiveSample.fromJson(Map<String,dynamic>.from(e))).where((s)=>now.difference(s.time)<=const Duration(days:7)).toList()..sort((a,b)=>a.time.compareTo(b.time));
    } catch (_) { return []; }
  }

  static Future<void> recordIfDue(double cpu,double ram) async {
    final samples=await load();
    final now=DateTime.now();
    if(samples.isNotEmpty && now.difference(samples.last.time)<const Duration(minutes:15))return;
    samples.removeWhere((s)=>now.difference(s.time)>const Duration(days:7));
    samples.add(PredictiveSample(time:now,cpu:cpu,ram:ram));
    await _storage.write(key:_key,value:jsonEncode(samples.map((s)=>s.toJson()).toList()));
  }
}
