import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:aplikasi/screens/dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _starsCtrl; // 👈 ganti confetti

  late Animation<double> _fade;
  late Animation<double> _slide;

  bool _showStars = false; // 👈 trigger tampil bintang

  @override
  void initState() {
    super.initState();

    final randomDuration = 2500 + Random().nextInt(2000);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _progressCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: randomDuration),
    );

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    _slide = Tween<double>(
      begin: 16,
      end: 0,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
    _progressCtrl.forward();

    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 👇 jalankan bintang
        setState(() => _showStars = true);
        _starsCtrl.forward();

        Future.delayed(const Duration(milliseconds: 2500), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (_, __, ___) => const DashboardScreen(),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
                child: child,
              ),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _progressCtrl.dispose();
    _starsCtrl.dispose(); // 👈 ganti confetti
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5BB9D6),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blob kanan atas
            Positioned(top: -80, right: -60, child: _blob(220)),

            // Blob kiri bawah
            Positioned(bottom: -60, left: -50, child: _blob(180)),

            // Konten utama
            AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => Opacity(
                opacity: _fade.value,
                child: Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo Lottie
                  SizedBox(
                    width: 400,
                    height: 400,
                    child: Lottie.asset(
                      'assets/lottie/Becket_Trash.json',
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Nama app
                  const Text(
                    'TrashBin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Turning waste into value',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 152),

                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => Container(
                      width: 190,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progressCtrl.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Teks loading
                  Text(
                    'Memuat...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            // 👇 Animasi bintang melayang naik
            if (_showStars)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _starsCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _StarsPainter(progress: _starsCtrl.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      shape: BoxShape.circle,
    ),
  );
}

// ===== BINTANG PAINTER =====
class _StarsPainter extends CustomPainter {
  final double progress;

  // Generate bintang sekali, posisi acak tapi konsisten
  static final _rng = Random(42);
  static final List<_Star> _stars = List.generate(30, (_) => _Star(_rng));

  _StarsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in _stars) {
      // Setiap bintang punya delay berbeda
      final t = ((progress - star.delay) / (1.0 - star.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Posisi: mulai dari bawah, naik ke atas
      final x = star.x * size.width;
      final startY = size.height * (0.5 + star.startOffset);
      final endY = size.height * (star.startOffset - 0.3);
      final y = startY + (endY - startY) * Curves.easeOut.transform(t);

      // Opacity: muncul lalu fade out
      final opacity = t < 0.5 ? t / 0.5 : 1.0 - ((t - 0.5) / 0.5);

      final paint = Paint()
        ..color = star.color.withOpacity(opacity * 0.9)
        ..style = PaintingStyle.fill;

      // Gambar bintang kecil
      _drawStar(canvas, Offset(x, y), star.size, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const points = 4;
    const outerR = 1.0;
    const innerR = 0.4;

    for (int i = 0; i < points * 2; i++) {
      final angle = (pi / points) * i - pi / 2;
      final r = i.isEven ? outerR * size : innerR * size;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.progress != progress;
}

class _Star {
  final double x;
  final double startOffset;
  final double size;
  final double delay;
  final Color color;

  _Star(Random rng)
    : x = rng.nextDouble(),
      startOffset = 0.3 + rng.nextDouble() * 0.4,
      size = 4 + rng.nextDouble() * 8,
      delay = rng.nextDouble() * 0.5,
      color = [
        Colors.white,
        const Color(0xFFFFE066),
        const Color(0xFF6BF0C8),
        const Color(0xFFB388FF),
      ][rng.nextInt(4)];
}
