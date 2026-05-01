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

  final List<Map<String, dynamic>> logs = [
    {"type": "Botol", "time": DateTime(2026, 4, 1, 10, 12)},
    {"type": "Kaleng", "time": DateTime(2026, 4, 1, 11, 30)},
    {"type": "Botol", "time": DateTime(2026, 4, 2, 9, 10)},
    {"type": "Kaleng", "time": DateTime(2026, 4, 2, 14, 22)},
    {"type": "Botol", "time": DateTime(2026, 4, 3, 16, 45)},
  ];

  List<Map<String, dynamic>> get filteredLogs {
    if (selectedDate == null) return logs;
    return logs.where((log) {
      DateTime t = log["time"];
      return t.year == selectedDate!.year &&
          t.month == selectedDate!.month &&
          t.day == selectedDate!.day;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> groupLogs() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var log in filteredLogs) {
      DateTime t = log["time"];
      String key = DateFormat('dd MMM yyyy').format(t);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(log);
    }
    return grouped;
  }

  Map<String, int> countPerType(List<Map<String, dynamic>> items) {
    int botol = 0;
    int kaleng = 0;
    for (var item in items) {
      if (item["type"] == "Botol") botol++;
      if (item["type"] == "Kaleng") kaleng++;
    }
    return {"botol": botol, "kaleng": kaleng, "total": botol + kaleng};
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupLogs();

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
                // Warna berubah kalau filter aktif
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

          // List
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

                List<Map<String, dynamic>> logs = snapshot.data!.docs.map((
                  doc,
                ) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    "type": data["type"],
                    "time": (data["time"] as Timestamp).toDate(),
                  };
                }).toList();

                if (selectedDate != null) {
                  logs = logs.where((log) {
                    DateTime t = log["time"];
                    return t.year == selectedDate!.year &&
                        t.month == selectedDate!.month &&
                        t.day == selectedDate!.day;
                  }).toList();
                }

                Map<String, List<Map<String, dynamic>>> grouped = {};
                for (var log in logs) {
                  DateTime t = log["time"];
                  String key = DateFormat('dd MMM yyyy').format(t);
                  grouped.putIfAbsent(key, () => []);
                  grouped[key]!.add(log);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: grouped.entries.map((entry) {
                    final items = entry.value;
                    int botol = 0;
                    int kaleng = 0;
                    for (var item in items) {
                      if (item["type"] == "Botol") botol++;
                      if (item["type"] == "Kaleng") kaleng++;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                        // Hapus divider bawaan ExpansionTile
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
                          subtitle: Text(
                            "${botol + kaleng} item",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
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
                            _buildItem(
                              imagePath: 'assets/lottie/bottle.png',
                              label: "Botol",
                              count: botol,
                              color: const Color(0xFF2C6FAC),
                              bgColor: const Color(0xFFEBF4FD),
                            ),
                            _buildItem(
                              imagePath: 'assets/lottie/can.png',
                              label: "Kaleng",
                              count: kaleng,
                              color: const Color(0xFFBA7517),
                              bgColor: const Color(0xFFFFF4E0),
                            ),
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

  Widget _buildItem({
    required String imagePath, // 👈 ganti IconData → String
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ), // 👈 pakai PNG
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
