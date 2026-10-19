import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PredictiveSample {
  const PredictiveSample({
    required this.time,
    required this.cpu,
    required this.ram,
  });

  final DateTime time;
  final double cpu;
  final double ram;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'cpu': cpu,
        'ram': ram,
      };

  factory PredictiveSample.fromJson(Map<String, dynamic> json) =>
      PredictiveSample(
        time: DateTime.parse(json['time'] as String),
        cpu: (json['cpu'] as num).toDouble(),
        ram: (json['ram'] as num).toDouble(),
      );
}

class PredictiveHistory {
  PredictiveHistory._();

  static const String _key = 'tikplus.resource.history.v1';

  static Future<List<PredictiveSample>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final now = DateTime.now();
      return (jsonDecode(raw) as List)
          .map((item) => PredictiveSample.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .where((sample) =>
              now.difference(sample.time) <= const Duration(days: 7))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    } catch (_) {
      return [];
    }
  }

  static Future<void> recordIfDue(double cpu, double ram) async {
    final samples = await load();
    final now = DateTime.now();
    if (samples.isNotEmpty &&
        now.difference(samples.last.time) < const Duration(minutes: 15)) {
      return;
    }
    samples.removeWhere(
        (sample) => now.difference(sample.time) > const Duration(days: 7));
    samples.add(PredictiveSample(time: now, cpu: cpu, ram: ram));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(samples.map((sample) => sample.toJson()).toList()),
    );
  }
}
