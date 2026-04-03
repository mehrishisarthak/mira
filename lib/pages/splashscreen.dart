import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:google_fonts/google_fonts.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/services/update_service.dart';
import 'package:mira/pages/update_screen.dart';
import 'dart:async';

import 'package:http/http.dart' as http;

class SplashScreen extends StatefulWidget {
  // 1. Accept the destination screen dynamically
  final Widget nextScreen;
  final http.Client? httpClient;
  
  const SplashScreen({super.key, required this.nextScreen, this.httpClient});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup the "Breathing" Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // 2. Start the Boot Sequence
    _bootSequence();
  }

  void _bootSequence() async {
    // Stage 1: Wait for native splash to clear (tiny delay ensures smooth handover)
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Stage 2: Fade In Logo
    if (mounted) _controller.forward();

    // Stage 3: Haptic "Heartbeat" (Optional: Mechanical feel)
    await Future.delayed(const Duration(milliseconds: 800));
    HapticFeedback.lightImpact();

    // Stage 4: Network Protocols (Update Check)
    final updateResult = await UpdateService.autoCheck(client: widget.httpClient);

    // Stage 5: Navigate based on Update Status
    if (mounted) {
      if (updateResult.status == UpdateStatus.forceUpdate) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => UpdateScreen(result: updateResult)),
        );
        return;
      }

      if (updateResult.status == UpdateStatus.updateAvailable) {
        // If optional update, we show it but allow skipping
        // For now, we go to update screen first. 
        // The UpdateScreen handles the skip logic.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => UpdateScreen(result: updateResult)),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          // 2. Use the dynamic nextScreen here
          pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // A subtle fade transition instead of a slide
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define the Brand Color (Tactical Green or Red)
    // Hardcoded here for the boot sequence
    const Color brandColor = Colors.greenAccent; 

    return Scaffold(
      backgroundColor: kMiraMatteBlack,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- THE LOGO ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: brandColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(alpha: 0.2 * _opacityAnimation.value),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.privacy_tip_outlined, 
                        size: 64,
                        color: brandColor,
                      ),
                    ),
                    
                    const SizedBox(height: 40),

                    // --- THE TEXT ---
                    Text(
                      'M I R A',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(
                            color: brandColor.withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // --- THE SUBTITLE (Loading State) ---
                    Text(
                      'INITIALIZING...',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: Colors.white38,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}