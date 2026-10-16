import 'package:flutter_test/flutter_test.dart';
import 'package:tikplus_ultra/models/router_health_assessment.dart';

void main() {
  group('RouterHealthAssessment', () {
    test('unknown metrics never appear healthy', () {
      final result = RouterHealthAssessment.evaluate();
      expect(result.overallLevel, RouterHealthLevel.unknown);
      expect(result.findings.every((item) => item.level == RouterHealthLevel.unknown), isTrue);
    });

    test('high CPU or memory produces warnings and critical states', () {
      final warning = RouterHealthAssessment.evaluate(cpuPercent: 78, memoryPercent: 40);
      expect(warning.findings.first.level, RouterHealthLevel.warning);
      expect(warning.overallLevel, RouterHealthLevel.warning);

      final critical = RouterHealthAssessment.evaluate(cpuPercent: 95, memoryPercent: 95);
      expect(critical.overallLevel, RouterHealthLevel.critical);
    });

    test('healthy readings remain advisory and read-only', () {
      final result = RouterHealthAssessment.evaluate(
        cpuPercent: 20,
        memoryPercent: 35,
        temperatureCelsius: 50,
      );
      expect(result.overallLevel, RouterHealthLevel.healthy);
      expect(result.findings.every((item) => item.recommendation.isNotEmpty), isTrue);
    });
  });
}
