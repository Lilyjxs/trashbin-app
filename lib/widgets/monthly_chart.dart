import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MonthlyChart extends StatelessWidget {
  final List<double> bottleData;
  final List<double> canData;

  const MonthlyChart({
    super.key,
    required this.bottleData,
    required this.canData,
  });

  double calculateInterval(double maxValue) {
    const int targetLines = 5;
    double raw = maxValue / targetLines;

    double base = 1;
    while (raw >= 10) {
      raw /= 10;
      base *= 10;
    }

    if (raw < 2) {
      raw = 2;
    } else if (raw < 5) {
      raw = 5;
    } else {
      raw = 10;
    }

    return raw * base;
  }

  @override
  Widget build(BuildContext context) {
    final totalData = List.generate(
      bottleData.length,
      (i) => bottleData[i] + canData[i],
    );

    final allData = [...bottleData, ...canData, ...totalData];

    double maxData = allData.reduce((a, b) => a > b ? a : b);

    // 🔥 biar tetap keliatan walau kecil
    if (maxData < 5) maxData = 5;

    final interval = calculateInterval(maxData);
    final maxY = (maxData / interval).ceil() * interval;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF6FF), Color(0xFFD6ECFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: bottleData.length - 1,
                minY: 0,
                maxY: maxY,

                // 🔥 ANIMASI HALUS
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.black87,
                    getTooltipItems: (spots) {
                      // urutin biar selalu tampil: Botol → Kaleng → Total
                      spots.sort((a, b) => a.barIndex.compareTo(b.barIndex));

                      return spots.map((spot) {
                        String label = '';

                        if (spot.barIndex == 0) label = 'Total';
                        if (spot.barIndex == 1) label = 'Botol';
                        if (spot.barIndex == 2) label = 'Kaleng';

                        return LineTooltipItem(
                          '$label\n${spot.y.toInt()} item\nHari ${spot.x.toInt() + 1}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.blue.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),

                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "${value.toInt() + 1}",
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),

                borderData: FlBorderData(show: false),

                // 🔥 ANIMASI LINE
                lineBarsData: [
                  // 🟢 TOTAL (taruh paling belakang)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: Colors.green.withOpacity(0.4), // 🔥 biar ga nutup
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.08),
                    ),
                    spots: List.generate(
                      totalData.length,
                      (i) => FlSpot(i.toDouble(), totalData[i]),
                    ),
                  ),

                  // 🔵 BOTOL (di depan)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                    spots: List.generate(
                      bottleData.length,
                      (i) => FlSpot(i.toDouble(), bottleData[i]),
                    ),
                  ),

                  // 🟡 KALENG (paling depan)
                  LineChartBarData(
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.1),
                    ),
                    spots: List.generate(
                      canData.length,
                      (i) => FlSpot(i.toDouble(), canData[i]),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 600), // 🔥 animasi masuk
              curve: Curves.easeOut,
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 LEGEND
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              LegendItem(color: Colors.blue, text: "Botol"),
              SizedBox(width: 16),
              LegendItem(color: Colors.orange, text: "Kaleng"),
              SizedBox(width: 16),
              LegendItem(color: Colors.green, text: "Total"),
            ],
          ),
        ],
      ),
    );
  }
}

// 🔹 LEGEND
class LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const LegendItem({required this.color, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
