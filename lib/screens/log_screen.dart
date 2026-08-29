import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  DateTime? selectedDate;

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF4F9),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          "Log Aktivitas",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.filter_alt_outlined,
                color: selectedDate != null
                    ? const Color(0xFF2C6FAC)
                    : Colors.black54,
              ),
              onPressed: pickDate,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chip tanggal
          if (selectedDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF4FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6E4F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Color(0xFF2C6FAC),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yyyy').format(selectedDate!),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Color(0xFF2C6FAC),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => selectedDate = null),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF2C6FAC),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('logs')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF5BB9D6),
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.black12,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Belum ada aktivitas",
                          style: TextStyle(color: Colors.black38, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Parse semua log dari Firestore
                List<Map<String, dynamic>> logs = snapshot.data!.docs.map((
                  doc,
                ) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    "type": data["type"] ?? "-",
                    "confidence": data["confidence"],
                    "sensor": data["sensor"] ?? "-",
                    "status": data["status"] ?? "-",
                    "time":
                        (data["time"] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                  };
                }).toList();

                // Filter by date kalau ada
                if (selectedDate != null) {
                  logs = logs.where((log) {
                    DateTime t = log["time"];
                    return t.year == selectedDate!.year &&
                        t.month == selectedDate!.month &&
                        t.day == selectedDate!.day;
                  }).toList();
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.black12),
                        const SizedBox(height: 12),
                        const Text(
                          "Tidak ada log pada tanggal ini",
                          style: TextStyle(color: Colors.black38, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Group by tanggal
                Map<String, List<Map<String, dynamic>>> grouped = {};
                for (var log in logs) {
                  String key = DateFormat('dd MMM yyyy').format(log["time"]);
                  grouped.putIfAbsent(key, () => []);
                  grouped[key]!.add(log);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: grouped.entries.map((entry) {
                    final items = entry.value;
                    int botol = items.where((e) => e["type"] == "Botol").length;
                    int kaleng = items
                        .where((e) => e["type"] == "Kaleng")
                        .length;
                    int ditolak = items
                        .where((e) => e["status"] == "DITOLAK")
                        .length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD6E4F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                "${items.length} item",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black38,
                                ),
                              ),
                              if (ditolak > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "$ditolak ditolak",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          iconColor: Colors.black38,
                          collapsedIconColor: Colors.black38,
                          children: [
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: const Color(0xFFEFF4F9),
                              indent: 16,
                              endIndent: 16,
                            ),
                            const SizedBox(height: 8),

                            // Summary botol & kaleng
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  _summaryChip(
                                    imagePath: 'assets/lottie/bottle.png',
                                    label: "Botol",
                                    count: botol,
                                    color: const Color(0xFF2C6FAC),
                                    bgColor: const Color(0xFFEBF4FD),
                                  ),
                                  const SizedBox(width: 10),
                                  _summaryChip(
                                    imagePath: 'assets/lottie/can.png',
                                    label: "Kaleng",
                                    count: kaleng,
                                    color: const Color(0xFFBA7517),
                                    bgColor: const Color(0xFFFFF4E0),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: const Color(0xFFEFF4F9),
                              indent: 16,
                              endIndent: 16,
                            ),
                            const SizedBox(height: 8),

                            // Detail per item
                            ...items.map((log) => _logItem(log)).toList(),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required String imagePath,
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Image.asset(imagePath, width: 20, height: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logItem(Map<String, dynamic> log) {
    final type = log["type"] as String;
    final confidence = log["confidence"];
    final sensor = log["sensor"] as String;
    final status = log["status"] as String;
    final time = log["time"] as DateTime;

    final isDiterima = status == "DITERIMA";
    final isKaleng = type == "Kaleng";

    final typeColor = isKaleng
        ? const Color(0xFFBA7517)
        : const Color(0xFF2C6FAC);
    final typeBg = isKaleng ? const Color(0xFFFFF4E0) : const Color(0xFFEBF4FD);
    final imagePath = isKaleng
        ? 'assets/lottie/can.png'
        : 'assets/lottie/bottle.png';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDiterima ? Colors.transparent : Colors.red.shade100,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris atas: icon + type + waktu + status badge
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    type == "Tidak Diketahui"
                        ? 'assets/lottie/bottle.png'
                        : imagePath,
                    fit: BoxFit.contain,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm:ss').format(time),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDiterima
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDiterima
                          ? Colors.green.shade600
                          : Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            const SizedBox(height: 8),

            // Baris bawah: confidence + sensor
            Row(
              children: [
                // Confidence
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 14,
                        color: Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "CNN",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        confidence != null
                            ? "${confidence.toStringAsFixed(1)}%"
                            : "-",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sensor
                Row(
                  children: [
                    Icon(Icons.sensors, size: 14, color: Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      "Sensor",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sensor,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
