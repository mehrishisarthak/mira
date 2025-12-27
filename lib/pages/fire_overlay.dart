import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CinematicNukeOverlay extends StatefulWidget {
  final bool isTriggered;
  final VoidCallback onAnimationComplete;

  const CinematicNukeOverlay({
    super.key,
    required this.isTriggered,
    required this.onAnimationComplete,
  });

  @override
  State<CinematicNukeOverlay> createState() => _CinematicNukeOverlayState();
}

class _CinematicNukeOverlayState extends State<CinematicNukeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Animation Phases
  late Animation<double> _flashAnimation;     // Initial blinding white light
  late Animation<double> _blastScale;         // The main expanding fireball
  late Animation<double> _shockwaveScale;     // The faster, translucent ring
  late Animation<double> _overlayOpacity;     // Fading out the whole effect
  
  // Text Animations
  late Animation<double> _textOpacity;
  late Animation<double> _textSpacing;
  late Animation<double> _textDrift;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800), // Longer, cinematic duration
    );

    // 1. The Blinding Flash (Ignition)
    // Instant spike to white, fast decay
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 80),
    ]).animate(_controller);

    // 2. The Main Fireball Expansion
    // Starts fast (explosion), slows down as it fills screen (Physics feel)
    _blastScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutExpo),
    );

    // 3. The Shockwave
    // Moves faster than the fireball, slightly ahead
    _shockwaveScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCirc),
    );

    // 4. Overall Fade Out
    // Dissolves the fire into nothingness at the end
    _overlayOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );

    // 5. Text Animations
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _textSpacing = Tween<double>(begin: 2.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    
    _textDrift = Tween<double>(begin: 20.0, end: -20.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
        _controller.reset();
      }
    });
  }

  @override
  void didUpdateWidget(CinematicNukeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTriggered && !oldWidget.isTriggered) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating && !widget.isTriggered) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned.fill(
          child: Opacity(
            opacity: _overlayOpacity.value,
            child: Stack(
              children: [
                // Layer 1: The Fire & Shockwave Painter
                CustomPaint(
                  painter: NukePainter(
                    blastProgress: _blastScale.value,
                    shockwaveProgress: _shockwaveScale.value,
                  ),
                  size: Size.infinite,
                ),

                // Layer 2: The Initial White Flash Overlay
                if (_flashAnimation.value > 0)
                  Container(
                    color: Colors.white.withOpacity(_flashAnimation.value * 0.8),
                  ),

                // Layer 3: The Cinematic Text
                Center(
                  child: Transform.translate(
                    offset: Offset(0, _textDrift.value),
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Using a ShaderMask for text to give it a "burnt" look
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFFFCC00)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: const Icon(
                              Icons.warning_amber_rounded, 
                              size: 60, 
                              color: Colors.white
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "FORGETTING EVERYTHING",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: _textSpacing.value,
                              shadows: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// THE RENDER ENGINE (CustomPainter)
// ---------------------------------------------------------------------------

class NukePainter extends CustomPainter {
  final double blastProgress;
  final double shockwaveProgress;

  NukePainter({required this.blastProgress, required this.shockwaveProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Max radius covers the screen corners (hypotenuse)
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);

    // 1. DRAW SHOCKWAVE (Fast, thinner ring)
    if (shockwaveProgress > 0 && shockwaveProgress < 1.0) {
      final shockRadius = maxRadius * shockwaveProgress;
      final shockPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 50 * (1.0 - shockwaveProgress) // Thins out as it expands
        ..color = Colors.white.withOpacity(0.3 * (1.0 - shockwaveProgress))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20); // Bloom effect

      canvas.drawCircle(center, shockRadius, shockPaint);
    }

    // 2. DRAW MAIN FIREBALL
    if (blastProgress > 0) {
      final blastRadius = maxRadius * blastProgress * 1.2; // Overshoot slightly

      // We use a RadialGradient to simulate the "Core Heat" vs "Outer Fire"
      final rect = Rect.fromCircle(center: center, radius: blastRadius);
      final gradient = ui.Gradient.radial(
        center,
        blastRadius,
        [
          Colors.white,        // Core (Hot)
          Colors.yellowAccent, // Inner
          Colors.deepOrange,   // Mid
          Colors.red.shade900, // Outer
          Colors.black87,      // Smoke/Char
          Colors.transparent   // Edge
        ],
        [0.0, 0.1, 0.3, 0.6, 0.9, 1.0], // Stops
      );

      final blastPaint = Paint()
        ..shader = gradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10); // Softens edges

      canvas.drawCircle(center, blastRadius, blastPaint);
    }
  }

  @override
  bool shouldRepaint(covariant NukePainter oldDelegate) {
    return oldDelegate.blastProgress != blastProgress ||
           oldDelegate.shockwaveProgress != shockwaveProgress;
  }
}