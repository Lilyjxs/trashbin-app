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
    // Ambil hari ini (1-based), maksimal sesuai panjang data
    final today = DateTime.now().day;
    final cutoff = today.clamp(1, bottleData.length);

    // Potong data sampai hari ini saja
    final trimmedBottle = bottleData.sublist(0, cutoff);
    final trimmedCan = canData.sublist(0, cutoff);
    final trimmedTotal = List.generate(
      cutoff,
      (i) => trimmedBottle[i] + trimmedCan[i],
    );

    final allData = [...trimmedBottle, ...trimmedCan, ...trimmedTotal];
    double maxData = allData.isEmpty
        ? 5
        : allData.reduce((a, b) => a > b ? a : b);
    if (maxData < 5) maxData = 5;

    final interval = calculateInterval(maxData);
    final maxY = (maxData / interval).ceil() * interval;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (cutoff - 1).toDouble(),
                minY: 0,
                maxY: maxY,

                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E2A3A),
                    getTooltipItems: (spots) {
                      spots.sort((a, b) => a.barIndex.compareTo(b.barIndex));
                      return spots.map((spot) {
                        final labels = ['Total', 'Botol', 'Kaleng'];
                        final colors = [
                          Colors.green,
                          Colors.blue,
                          Colors.orange,
                        ];
                        final label = labels[spot.barIndex];
                        final day = spot.x.toInt() + 1;

                        // Tambah tanggal hanya di baris pertama (Total)
                        if (spot.barIndex == 0) {
                          return LineTooltipItem(
                            '',
                            const TextStyle(fontSize: 0),
                            children: [
                              TextSpan(
                                text: 'Tgl $day\n',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: '$label: ${spot.y.toInt()}',
                                style: TextStyle(
                                  color: colors[spot.barIndex],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        }

                        return LineTooltipItem(
                          '$label: ${spot.y.toInt()}',
                          TextStyle(
                            color: colors[spot.barIndex],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withOpacity(0.12),
                    strokeWidth: 1,
                  ),
                ),

                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: cutoff <= 10 ? 1 : 5,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt() + 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            "$day",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
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

                lineBarsData: [
                  // 🟢 TOTAL
                  _buildLine(
                    spots: trimmedTotal,
                    color: Colors.green,
                    opacity: 0.35,
                    width: 2.5,
                  ),
                  // 🔵 BOTOL
                  _buildLine(
                    spots: List<double>.from(trimmedBottle),
                    color: Colors.blue,
                    opacity: 0.12,
                    width: 2.5,
                  ),
                  // 🟠 KALENG
                  _buildLine(
                    spots: List<double>.from(trimmedCan),
                    color: Colors.orange,
                    opacity: 0.12,
                    width: 2.5,
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            ),
          ),

          const SizedBox(height: 14),

          // LEGEND
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(color: Colors.blue, label: "Botol"),
              SizedBox(width: 20),
              _LegendDot(color: Colors.orange, label: "Kaleng"),
              SizedBox(width: 20),
              _LegendDot(color: Colors.green, label: "Total"),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine({
    required List<double> spots,
    required Color color,
    required double opacity,
    required double width,
  }) {
    return LineChartBarData(
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false), // ← titik dihilangkan
      belowBarData: BarAreaData(show: true, color: color.withOpacity(opacity)),
      spots: List.generate(spots.length, (i) => FlSpot(i.toDouble(), spots[i])),
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
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
