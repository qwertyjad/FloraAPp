// ignore_for_file: library_private_types_in_public_api

import 'package:florafolium_app/main.dart';
import 'package:flutter/material.dart';
import 'dart:async';
// Replace with the main screen you want to navigate to

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Logo Image
          Center(
            child: Image.asset(
              'assets/logo.png',
              width: 500, // Adjust the logo size as needed
            ),
          ),
        ],
      ),
    );
  }
}
