import 'package:aplikasi/screens/about_screen.dart';
import 'package:aplikasi/screens/log_screen.dart';
import 'package:aplikasi/screens/settings_screen.dart';
import 'package:aplikasi/widgets/monthly_chart.dart';
import 'package:aplikasi/widgets/status_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final bool isOnline = true;

  Key _streamKey = UniqueKey();
  double _dragOffset = 0;
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _streamKey = UniqueKey();
      _isRefreshing = false;
    });
  }

  Future<Map<String, dynamic>> fetchData() async {
    final snapshot = await FirebaseFirestore.instance.collection('logs').get();

    int totalBotol = 0;
    int totalKaleng = 0;
    String lastItem = "-";

    List<double> bottleData = List.generate(31, (i) => 0);
    List<double> canData = List.generate(31, (i) => 0);

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'];
      final timestamp = data['time'];

      DateTime date;

      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is int) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      } else {
        continue;
      }

      int day = date.day - 1;

      if (type == 'Botol') {
        totalBotol++;
        if (day >= 0 && day < bottleData.length) bottleData[day]++;
        lastItem = "Botol";
        print("Bottle Data: $bottleData");
        print("Can Data: $canData");
      }

      if (type == 'Kaleng') {
        totalKaleng++;
        if (day >= 0 && day < canData.length) canData[day]++;
        lastItem = "Kaleng";
        print("Bottle Data: $bottleData");
        print("Can Data: $canData");
      }
    }

    return {
      "totalBotol": totalBotol,
      "totalKaleng": totalKaleng,
      "totalMonth": totalBotol + totalKaleng,
      "lastItem": lastItem,
      "bottleData": bottleData,
      "canData": canData,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildDrawer(context),
      backgroundColor: const Color(0xffEFF4F9),
      body: Stack(
        children: [
          // 🔵 BACKGROUND BIRU PENGISI AREA KOSONG SAAT DITARIK
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _dragOffset + 2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5BB9D6), Color(0xFF3AA0C4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // 📄 KONTEN UTAMA
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is OverscrollNotification &&
                  notification.overscroll < 0) {
                // Ditarik ke bawah (overscroll atas)
                setState(() {
                  _dragOffset = (_dragOffset + (-notification.overscroll) * 0.5)
                      .clamp(0, 100);
                });
              }

              if (notification is ScrollEndNotification) {
                if (_dragOffset > 50 && !_isRefreshing) {
                  _handleRefresh();
                }
                // Smooth balik ke 0
                _animateOffsetBack();
              }

              return false;
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: StreamBuilder<QuerySnapshot>(
                key: _streamKey,
                stream: FirebaseFirestore.instance
                    .collection('logs')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  int totalBotol = 0;
                  int totalKaleng = 0;
                  String lastItem = "-";

                  List<double> bottleData = List.generate(31, (i) => 0);
                  List<double> canData = List.generate(31, (i) => 0);

                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'];
                    final timestamp = data['time'];

                    DateTime date = (timestamp as Timestamp).toDate();
                    int day = date.day - 1;

                    if (type == 'Botol') {
                      totalBotol++;
                      if (day >= 0 && day < bottleData.length)
                        bottleData[day]++;
                      lastItem = "Botol";
                    }

                    if (type == 'Kaleng') {
                      totalKaleng++;
                      if (day >= 0 && day < canData.length) canData[day]++;
                      lastItem = "Kaleng";
                    }
                  }

                  final data = {
                    "totalBotol": totalBotol,
                    "totalKaleng": totalKaleng,
                    "totalMonth": totalBotol + totalKaleng,
                    "lastItem": lastItem,
                    "bottleData": bottleData,
                    "canData": canData,
                  };

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 🔵 HEADER
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            ClipPath(
                              clipper: TopCurveClipper(),
                              child: Container(
                                height: 520,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF5BB9D6),
                                      Color(0xFF3AA0C4),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),

                            SafeArea(
                              child: Column(
                                children: [
                                  // 🌀 INDIKATOR REFRESH
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: (_dragOffset > 15 || _isRefreshing)
                                        ? Padding(
                                            key: const ValueKey('indicator'),
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                              bottom: 2,
                                            ),
                                            child: _isRefreshing
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : Icon(
                                                    _dragOffset > 50
                                                        ? Icons
                                                              .keyboard_double_arrow_up_rounded
                                                        : Icons
                                                              .keyboard_double_arrow_down_rounded,
                                                    color: Colors.white
                                                        .withOpacity(
                                                          (_dragOffset / 100)
                                                              .clamp(0.3, 1.0),
                                                        ),
                                                    size: 24,
                                                  ),
                                          )
                                        : const SizedBox(
                                            key: ValueKey('empty'),
                                            height: 0,
                                          ),
                                  ),

                                  // 🔷 APP BAR
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            SizedBox(width: 6),
                                            StreamBuilder<DocumentSnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('settings')
                                                  .doc('app_config')
                                                  .snapshots(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Text(
                                                    "Loading...",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 17,
                                                    ),
                                                  );
                                                }

                                                if (!snapshot.hasData ||
                                                    !snapshot.data!.exists) {
                                                  return const Text(
                                                    "Unknown",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 17,
                                                    ),
                                                  );
                                                }

                                                final rawData = snapshot.data!
                                                    .data();

                                                if (rawData == null) {
                                                  return const Text(
                                                    "Unknown",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 17,
                                                    ),
                                                  );
                                                }

                                                final data =
                                                    rawData
                                                        as Map<String, dynamic>;
                                                final location =
                                                    data['location'] ??
                                                    "Unknown";

                                                return Text(
                                                  location.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        Builder(
                                          builder: (context) => IconButton(
                                            icon: const Icon(
                                              Icons.menu,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            onPressed: () => Scaffold.of(
                                              context,
                                            ).openDrawer(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // 🔴 STATUS
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? Colors.greenAccent
                                              : Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isOnline ? "ONLINE" : "OFFLINE",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  const Text(
                                    "Sistem aktif",
                                    style: TextStyle(color: Colors.white70),
                                  ),

                                  // 🧠 LOTTIE
                                  SizedBox(
                                    height: 250,
                                    child: Lottie.asset(
                                      'assets/lottie/vending.json',
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  // 📊 BOTOL & KALENG
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      InfoItem(
                                        title: "Botol",
                                        value: data["totalBotol"].toString(),
                                      ),
                                      InfoItem(
                                        title: "Kaleng",
                                        value: data["totalKaleng"].toString(),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🔻 CONTENT
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Transform.translate(
                                offset: const Offset(0, 20),
                                child: StatusCard(
                                  lastItem: data["lastItem"] as String,
                                  totalMonth: data["totalMonth"] as int,
                                  espStatus: "Online",
                                ),
                              ),

                              const SizedBox(height: 30),

                              const Text(
                                "Statistik Bulanan",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 12),

                              MonthlyChart(
                                bottleData: List<double>.from(
                                  data["bottleData"] as List,
                                ),
                                canData: List<double>.from(
                                  data["canData"] as List,
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _animateOffsetBack() {
    // Smooth animate offset kembali ke 0 tanpa AnimationController
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return false;
      setState(() {
        _dragOffset = (_dragOffset * 0.75);
      });
      return _dragOffset > 0.5;
    }).then((_) {
      if (mounted) setState(() => _dragOffset = 0);
    });
  }

  Drawer buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // 🔵 HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5BB9D6), Color(0xFF3AA0C4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.recycling, color: Colors.white, size: 40),
                SizedBox(height: 10),
                Text(
                  "TrashBin App",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Smart Recycling System",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _menuItem(
            icon: Icons.dashboard,
            title: "Dashboard",
            onTap: () => Navigator.pop(context),
          ),

          _menuItem(
            icon: Icons.list_alt,
            title: "Log Aktivitas",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogScreen()),
              );
            },
          ),

          _menuItem(
            icon: Icons.info_outline,
            title: "Tentang",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),

          _menuItem(
            icon: Icons.settings,
            title: "Pengaturan",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),

          const Spacer(),

          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "v1.0 • Skripsi Project",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔵 SHAPE
class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 40,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// 🔹 INFO ITEM
class InfoItem extends StatelessWidget {
  final String title;
  final String value;

  const InfoItem({required this.title, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.asset(
            title == "Botol"
                ? 'assets/lottie/bottle.png'
                : 'assets/lottie/can.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
