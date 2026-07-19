import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/pages/browser_chrome_providers.dart';
import 'package:qyx/pages/skeleton_loader.dart';

/// Isolated skeleton overlay — watches [browserChromeProvider] loading progress
/// independently so that onProgressChanged callbacks only rebuild this widget.
///
/// Visibility is hysteretic, not a direct read of `progress < 100`. The raw
/// signal is far too noisy to drive an overlay: `loadStart` resets progress to
/// 0 on *every* navigation, including subframes, redirects and SPA route
/// changes, so a naive binding strobes the skeleton over an already-painted
/// page. Two guards, which is what browsers do for load indicators:
///
///  * [_showDelay] — a load must still be running after this long before the
///    skeleton appears at all, so quick navigations never flash it.
///  * [_minVisible] — once shown it stays for at least this long, so a load
///    that finishes immediately after can't blink it straight back out.
class WebViewSkeletonOverlay extends ConsumerStatefulWidget {
  const WebViewSkeletonOverlay({super.key});

  @override
  ConsumerState<WebViewSkeletonOverlay> createState() =>
      _WebViewSkeletonOverlayState();
}

class _WebViewSkeletonOverlayState
    extends ConsumerState<WebViewSkeletonOverlay> {
  static const Duration _showDelay = Duration(milliseconds: 180);
  static const Duration _minVisible = Duration(milliseconds: 450);

  bool _visible = false;
  DateTime? _shownAt;
  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  bool get _isLoadingNow {
    final progress = ref.read(browserChromeProvider).loadingProgress;
    final url = ref.read(isGhostModeProvider)
        ? ref.read(ghostTabsProvider).safeActiveTab?.url ?? ''
        : ref.read(tabsProvider).safeActiveTab?.url ?? '';
    return progress < 100 && url.isNotEmpty;
  }

  void _sync() {
    if (!mounted) return;
    if (_isLoadingNow) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (_visible || _showTimer != null) return;
      _showTimer = Timer(_showDelay, () {
        _showTimer = null;
        if (!mounted || !_isLoadingNow) return;
        setState(() {
          _visible = true;
          _shownAt = DateTime.now();
        });
      });
      return;
    }

    _showTimer?.cancel();
    _showTimer = null;
    if (!_visible || _hideTimer != null) return;

    final shownFor = _shownAt == null
        ? _minVisible
        : DateTime.now().difference(_shownAt!);
    final remaining = _minVisible - shownFor;
    if (remaining <= Duration.zero) {
      setState(() => _visible = false);
      return;
    }
    _hideTimer = Timer(remaining, () {
      _hideTimer = null;
      if (!mounted || _isLoadingNow) return;
      setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // listen, not watch: these fire outside build, so _sync can setState
    // safely and the widget itself doesn't rebuild on every progress tick.
    ref.listen(browserChromeProvider.select((s) => s.loadingProgress),
        (_, __) => _sync());
    ref.listen(tabsProvider.select((p) => p.safeActiveTab?.url ?? ''),
        (_, __) => _sync());
    ref.listen(ghostTabsProvider.select((p) => p.safeActiveTab?.url ?? ''),
        (_, __) => _sync());
    ref.listen(isGhostModeProvider, (_, __) => _sync());

    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: Duration(milliseconds: _visible ? 150 : 400),
        curve: Curves.easeInOut,
        // Pause the shimmer's ticker when not loading. The loader stays mounted
        // (faded to 0), so without this its controller repaints ~60fps for the
        // life of the browser view, behind the page — stealing frames from
        // other app animations.
        child: TickerMode(
          enabled: _visible,
          child: const WebSkeletonLoader(),
        ),
      ),
    );
  }
}
