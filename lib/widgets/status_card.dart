import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String lastItem;
  final int totalMonth;
  final String espStatus;

  const StatusCard({
    super.key,
    required this.lastItem,
    required this.totalMonth,
    required this.espStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Container(
        // ❌ margin dihapus biar ga double padding
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD6E4F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: StatusItem(title: "Terakhir", value: lastItem),
            ),

            const DottedDivider(),

            Expanded(
              child: StatusItem(
                title: "Total Bulan Ini",
                value: "$totalMonth item",
              ),
            ),

            const DottedDivider(),

            Expanded(
              child: StatusItem(title: "ESP32", value: espStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusItem extends StatelessWidget {
  final String title;
  final String value;

  const StatusItem({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// 🔥 GARIS PUTUS-PUTUS
class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: CustomPaint(painter: DottedLinePainter()),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashHeight = 4;
    const dashSpace = 4;

    double startY = 0;

    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
