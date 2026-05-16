import 'package:flutter/material.dart';

import '../../../app/router.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRouter.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF14071F), Color(0xFF0D0518), Color(0xFF06030D)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 152,
                height: 152,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FF4B95),
                      blurRadius: 28,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFF7FC),
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: const Color(0xFFFFF7FC),
                      child: Image.asset(
                        'assets/branding/proteqher_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: Color(0xFFE72679),
                              child: Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ProteqMe',
                style: TextStyle(
                  color: Color(0xFFFFE5F1),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Personal Safety Companion',
                style: TextStyle(color: Color(0xFFB8A2C9), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
