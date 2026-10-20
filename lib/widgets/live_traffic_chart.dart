import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../providers/traffic_provider.dart';
import 'glass_card.dart';

String fmtBits(double b) {
  if (b >= 1e9) return '${(b / 1e9).toStringAsFixed(2)} Gbps';
  if (b >= 1e6) return '${(b / 1e6).toStringAsFixed(1)} Mbps';
  if (b >= 1e3) return '${(b / 1e3).toStringAsFixed(0)} Kbps';
  return '${b.toStringAsFixed(0)} bps';
}

class LiveTrafficChart extends StatelessWidget {
  final String name;
  final List<TrafficSample> data;

  const LiveTrafficChart({
    super.key,
    required this.name,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final last = data.isEmpty ? null : data.last;

    List<FlSpot> spots(double Function(TrafficSample) value) => [
          for (var i = 0; i < data.length; i++)
            FlSpot(i.toDouble(), value(data[i]) / 1e6),
        ];

    LineChartBarData line(List<FlSpot> values, Color color) =>
        LineChartBarData(
          spots: values,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withOpacity(0.12),
          ),
        );

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (last != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '↓ ${fmtBits(last.rx)}   ↑ ${fmtBits(last.tx)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'بانتظار بيانات حركة المرور...',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData:
                          const LineTouchData(enabled: false),
                      lineBarsData: [
                        line(spots((sample) => sample.rx),
                            const Color(0xFF6C8CFF)),
                        line(spots((sample) => sample.tx),
                            const Color(0xFF4ADE80)),
                      ],
                    ),
                    duration: Duration.zero,
                  ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(color: Color(0xFF6C8CFF), label: 'تنزيل'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF4ADE80), label: 'رفع'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
