import 'package:flutter/material.dart';

class BrandingScreen extends StatelessWidget {
  const BrandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF121212), // Deep dark background
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. The "Watermark" Logo
          Icon(
            Icons.remove_red_eye_outlined, // Or use your shutter icon
            size: 120,
            color: Colors.white.withOpacity(0.05), // Very subtle ghost look
          ),
          
          const SizedBox(height: 20),
          
          // 2. The App Name
          const Text(
            "M I R A", 
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8.0, // Spaced out for "premium" feel
            ),
          ),
          
          const SizedBox(height: 10),
          
          // 3. The Privacy Promise
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Text(
                "NO TRACKERS ACTIVE",
                style: TextStyle(
                  color: Colors.greenAccent.withOpacity(0.7),
                  fontSize: 12,
                  fontFamily: 'Courier', // Monospaced for hacker vibe
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}