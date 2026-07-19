import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/constants/app_fonts.dart';

import 'package:qyx/core/entities/theme_entity.dart';
import 'package:qyx/core/services/preferences_service.dart';
import 'package:qyx/pages/mainscreen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pages = PageController();
  int _current = 0;

  // Per-page content entrance controller — rebuilt on each page change
  late AnimationController _contentCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  // The three pages
  static const int _pageCount = 3;

  @override
  void initState() {
    super.initState();
    _buildContentAnimation();
    // Trigger entrance for page 0
    WidgetsBinding.instance.addPostFrameCallback((_) => _contentCtrl.forward());
  }

  void _buildContentAnimation() {
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)),
    );
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));
  }

  Future<void> _goTo(int index) async {
    if (index >= _pageCount) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();

    // Fade content out, switch page, fade back in
    await _contentCtrl.reverse();
    _pages.jumpToPage(index);

    setState(() => _current = index);

    _contentCtrl.forward();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await ref.read(preferencesServiceProvider).setFirstRun(false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Mainscreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kMiraMatteBlack,
        body: Stack(
          children: [
            // ── BACKGROUND visual for each page ─────────────────────────────
            PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _PageBackground(index: 0),
                _PageBackground(index: 1),
                _PageBackground(index: 2),
              ],
            ),

            // ── ANIMATED CONTENT ─────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: _PageContent(index: _current),
                ),
              ),
            ),

            // ── SKIP (top right) ─────────────────────────────────────────────
            if (_current < _pageCount - 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 20,
                child: GestureDetector(
                  onTap: _finish,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'SKIP',
                      style: jetBrainsMono(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            // ── BOTTOM CONTROLS (thumb zone) ──────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(28, 24, 28, bottom + 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(_pageCount, (i) {
                        final isActive = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(right: 8),
                          width: isActive ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.greenAccent
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),

                    // Primary CTA
                    _current < _pageCount - 1
                        ? _NextButton(
                            onTap: () => _goTo(_current + 1),
                          )
                        : _EnterButton(onTap: _finish),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page background visuals ───────────────────────────────────────────────────

class _PageBackground extends StatefulWidget {
  final int index;
  const _PageBackground({required this.index});

  @override
  State<_PageBackground> createState() => _PageBackgroundState();
}

class _PageBackgroundState extends State<_PageBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(index: widget.index, t: _anim.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final int index;
  final double t;

  const _BgPainter({required this.index, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = kMiraMatteBlack,
    );

    switch (index) {
      case 0:
        _paintSignal(canvas, size);
      case 1:
        _paintGhost(canvas, size);
      case 2:
        _paintShield(canvas, size);
    }
  }

  // Page 0 — expanding concentric rings (signal / broadcast)
  void _paintSignal(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.38;
    final maxR = size.width * 0.85;

    for (int i = 0; i < 4; i++) {
      final progress = ((t + i * 0.25) % 1.0);
      final r = maxR * progress;
      final opacity = (1.0 - progress) * 0.12;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = Colors.greenAccent.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Centre dot
    canvas.drawCircle(
      Offset(cx, cy),
      3 + t * 1.5,
      Paint()..color = Colors.greenAccent.withValues(alpha: 0.6),
    );
  }

  // Page 1 — particles fading out upward (ghost / vanishing)
  void _paintGhost(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (int i = 0; i < 18; i++) {
      final seedX = rng.nextDouble();
      rng.nextDouble(); // consume the paired draw to keep the seeded sequence stable
      final speed = 0.4 + rng.nextDouble() * 0.6;
      final phase = rng.nextDouble();

      final progress = ((t * speed + phase) % 1.0);
      final x = seedX * size.width;
      final y = size.height * (0.8 - progress * 0.65);
      final opacity = (1.0 - progress) * 0.18;
      final r = 1.5 + rng.nextDouble() * 2.5;

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  // Page 2 — static geometric grid (structure / control)
  void _paintShield(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.04 + t * 0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Accent horizontal line that scans
    final scanY = size.height * (0.3 + t * 0.1);
    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      Paint()
        ..color = Colors.greenAccent.withValues(alpha: 0.18)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ── Page text content ─────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final int index;
  const _PageContent({required this.index});

  static const List<_PageData> _data = [
    _PageData(
      eyebrow: 'WELCOME',
      headline: 'The web,\nas it should\nbe.',
      body:
          'Fast. Minimal. Yours alone.\nNo tracking. No noise. No compromise.',
    ),
    _PageData(
      eyebrow: 'GHOST PROTOCOL',
      headline: 'Browse.\nThen\nvanish.',
      body:
          'One tap activates a private session.\nHistory, cookies, traces — gone on close.',
    ),
    _PageData(
      eyebrow: 'YOUR RULES',
      headline: 'Private,\nalways one\ntap away.',
      body:
          'The ghost button lives in your address bar.\nNot buried. Not a setting. Always there.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final d = _data[index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Push content down from top — leave room for ambient background
          SizedBox(height: MediaQuery.of(context).size.height * 0.28),

          // Eyebrow
          Text(
            d.eyebrow,
            style: jetBrainsMono(
              fontSize: 10,
              color: Colors.greenAccent.withValues(alpha: 0.7),
              letterSpacing: 3.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Headline — the hero
          Text(
            d.headline,
            style: jetBrainsMono(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.12,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 24),

          // Body
          Text(
            d.body,
            style: jetBrainsMono(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.45),
              height: 1.65,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final String eyebrow;
  final String headline;
  final String body;
  const _PageData({
    required this.eyebrow,
    required this.headline,
    required this.body,
  });
}

// ── Bottom control buttons ────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NextButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NEXT',
              style: jetBrainsMono(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EnterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.greenAccent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ENTER QYX',
              style: jetBrainsMono(
                fontSize: 12,
                color: kMiraMatteBlack,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward,
              color: kMiraMatteBlack,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}




