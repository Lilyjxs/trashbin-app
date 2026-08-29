// splash_screen.dart
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

  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();

    final randomDuration = 500 + Random().nextInt(1500);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _progressCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: randomDuration),
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
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 700),
              pageBuilder: (_, __, ___) => const DashboardScreen(),
              transitionsBuilder: (_, anim, __, child) {
                // Fade + slide up — Material best practice
                final curved = CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
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
