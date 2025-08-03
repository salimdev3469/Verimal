import 'package:flutter/material.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'auth_wrapper.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  int _progress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLoadingAnimation();
  }

  void _startLoadingAnimation() {
    const totalDuration = 3; // saniye
    const steps = 100;
    const interval = Duration(milliseconds: (3000 ~/ 100)); // her adımda %1 artış

    _timer = Timer.periodic(interval, (timer) {
      setState(() {
        _progress+=2;
      });

      if (_progress >= 100) {
        timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7f32a8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/lottie/hourglass.json', width: 220),
            const SizedBox(height: 16),
            Image.asset('assets/images/verimalWhite.png', width: 220),
            const SizedBox(height: 24),
            Text(
              "Yükleniyor... $_progress%",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}