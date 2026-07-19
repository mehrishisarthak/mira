import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qyx/constants/app_fonts.dart';
import 'package:qyx/core/ui/qyx_mark.dart';
import 'package:http/http.dart' as http;

import 'package:qyx/core/entities/theme_entity.dart';
import 'package:qyx/core/services/update_service.dart';
import 'package:qyx/core/services/database_providers.dart';
import 'package:qyx/core/services/snapshot_service.dart';
import 'package:qyx/shell/browser/in_app_webview_engine.dart';
import 'package:qyx/pages/update_screen.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final http.Client? httpClient;

  const SplashScreen({super.key, required this.nextScreen, this.httpClient});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // --- Animation controllers ---
  late final List<AnimationController> _letterCtrls;
  late final AnimationController _scanCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _exitCtrl;

  // --- Driven animations ---
  late final List<Animation<double>> _letterFade;
  late final List<Animation<Offset>> _letterSlide;
  late final Animation<double> _scanPosition;
  late final Animation<double> _taglineFade;
  late final Animation<double> _screenFade;

  // --- Navigation sync ---
  bool _animDone = false;
  bool _checkDone = false;
  Widget? _destination;
  bool _navigating = false;

  static const List<String> _letters = ['Q', 'Y', 'X'];
  static const Color _accent = Colors.greenAccent;

  @override
  void initState() {
    super.initState();
    // Clear any orphaned snapshots from previous sessions
    unawaited(SnapshotService.clearStaleSnapshots());
    
    // Pre-warm the WebView engine during splash
    globalPreWarmedEngine = InAppWebViewEngine(isPrivate: false);

    _buildAnimations();
    _runAnimation();
    _runUpdateCheck();
  }

  void _buildAnimations() {
    _letterCtrls = List.generate(
      _letters.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
      ),
    );

    _letterFade = _letterCtrls
        .map((c) => Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOut),
            ))
        .toList();

    _letterSlide = _letterCtrls
        .map((c) =>
            Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero)
                .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
    );
    _scanPosition = Tween<double>(begin: -0.08, end: 1.08).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut),
    );

    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut),
    );

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _screenFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
  }

  Future<void> _runAnimation() async {
    // Brief pause so the native splash hands off cleanly
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Staggered letter reveal — each letter slides up and fades in
    for (int i = 0; i < _letters.length; i++) {
      unawaited(_letterCtrls[i].forward());
      await Future.delayed(const Duration(milliseconds: 80));
    }

    // Wait for the last letter to fully land
    await _letterCtrls.last.forward(from: _letterCtrls.last.value);
    await Future.delayed(const Duration(milliseconds: 55));
    if (!mounted) return;

    // Scan line sweeps left → right across the wordmark
    await _scanCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 35));
    if (!mounted) return;

    // Tagline fades in below
    await _taglineCtrl.forward();

    _animDone = true;
    _tryNavigate();
  }

  Future<void> _runUpdateCheck() async {
    final result = await UpdateService.autoCheck(client: widget.httpClient);
    if (!mounted) return;

    if (result.status == UpdateStatus.forceUpdate) {
      _destination = UpdateScreen(result: result);
    } else if (result.status == UpdateStatus.updateAvailable) {
      _destination = UpdateScreen(
        result: result,
        nextScreen: widget.nextScreen,
      );
    } else {
      _destination = widget.nextScreen;
    }

    _checkDone = true;
    _tryNavigate();
  }

  Future<void> _tryNavigate() async {
    if (!_animDone || !_checkDone || _navigating || !mounted) return;
    _navigating = true;

    // Let the final composed frame breathe for a moment
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      HapticFeedback.lightImpact();
    }

    await _exitCtrl.forward();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _destination ?? widget.nextScreen,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _letterCtrls) {
      c.dispose();
    }
    _scanCtrl.dispose();
    _taglineCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainSplash = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kMiraMatteBlack,
        body: FadeTransition(
          opacity: _screenFade,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── MARK ──────────────────────────────────────────────────────
                // Rides the first letter's fade so it leads the wordmark in.
                FadeTransition(
                  opacity: _letterFade.first,
                  child: QyxMark(size: 56, color: _accent),
                ),

                const SizedBox(height: 26),

                // ── WORDMARK ──────────────────────────────────────────────────
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Letters
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_letters.length, _buildLetter),
                    ),
                    // Scan line rendered on top via CustomPaint
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _scanPosition,
                        builder: (_, __) => CustomPaint(
                          painter: _ScanLinePainter(
                            position: _scanPosition.value,
                            color: _accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ── TAGLINE ───────────────────────────────────────────────────
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'YOUR WEB.  YOUR RULES.',
                    style: jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.28),
                      letterSpacing: 3.2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // If pre-warmed engine exists, mount it offstage to pay the cold-boot penalty
    if (globalPreWarmedEngine != null) {
      return Stack(
        children: [
          Offstage(
            child: globalPreWarmedEngine!.buildWidget(
              tabId: 'prewarm', 
              initialUrl: 'about:blank',
            ),
          ),
          mainSplash,
        ],
      );
    }
    return mainSplash;
  }

  Widget _buildLetter(int i) {
    return FadeTransition(
      opacity: _letterFade[i],
      child: SlideTransition(
        position: _letterSlide[i],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Text(
            _letters[i],
            style: jetBrainsMono(
              fontSize: 58,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scan line effect ─────────────────────────────────────────────────────────

class _ScanLinePainter extends CustomPainter {
  final double position; // −0.08 → 1.08, mapped to x
  final Color color;

  const _ScanLinePainter({required this.position, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (position < -0.06 || position > 1.06) return;

    final x = position * size.width;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Soft glow halo
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(x, size.height / 2), width: 28, height: size.height),
      Paint()
        ..color = color.withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Core line: vertical gradient so it fades at top and bottom edges
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(x, size.height / 2), width: 1.5, height: size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.18, 0.82, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.position != position;
}
