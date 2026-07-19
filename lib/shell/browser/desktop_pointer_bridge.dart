import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Forwards desktop trackpad gestures into the page (O-38).
///
/// Flutter delivers trackpad input as [PointerPanZoomUpdateEvent], a different
/// event class from the mouse wheel's `PointerScrollEvent`. WebView2 via
/// `flutter_inappwebview_windows` consumes the wheel but ignores pan-zoom
/// entirely, so a trackpad does nothing while a mouse works. Upstream closed
/// this as not-planned (flutter_inappwebview #2503 / #2511), so the events are
/// translated here and applied with JavaScript.
///
/// Deltas are accumulated and flushed on a [_flushInterval] timer rather than
/// evaluated per event: a trackpad emits ~60-120 updates/sec and one
/// `evaluateJavascript` round-trip each would swamp the IPC bridge (the same
/// concern as O-70 on the engine's own callbacks).
class DesktopPointerBridge extends StatefulWidget {
  const DesktopPointerBridge({
    super.key,
    required this.child,
    required this.runJs,
  });

  final Widget child;

  /// Evaluates a JavaScript source string in the page. No-ops before the
  /// controller exists.
  final Future<void> Function(String source) runJs;

  @override
  State<DesktopPointerBridge> createState() => _DesktopPointerBridgeState();
}

class _DesktopPointerBridgeState extends State<DesktopPointerBridge> {
  static const Duration _flushInterval = Duration(milliseconds: 16);

  /// Trackpad pan deltas are small; without a multiplier a full swipe barely
  /// moves the page. Tuned to feel close to Chrome on the same hardware.
  static const double _scrollMultiplier = 3.0;

  double _pendingDx = 0;
  double _pendingDy = 0;
  Timer? _flushTimer;

  /// Cumulative scale reported since the gesture began (1.0 at start), so the
  /// per-flush zoom step is the ratio against what we last applied.
  double _lastScale = 1.0;
  double _pageZoom = 1.0;
  bool _zoomDirty = false;

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, _flush);
  }

  void _flush() {
    _flushTimer = null;
    if (!mounted) return;

    final dx = _pendingDx;
    final dy = _pendingDy;
    _pendingDx = 0;
    _pendingDy = 0;

    if (dx != 0 || dy != 0) {
      // Negated: panDelta describes how the content is dragged, while
      // scrollBy takes a scroll offset — they run opposite each other.
      widget.runJs(
        'window.scrollBy(${(-dx * _scrollMultiplier).toStringAsFixed(2)},'
        ' ${(-dy * _scrollMultiplier).toStringAsFixed(2)});',
      );
    }

    if (_zoomDirty) {
      _zoomDirty = false;
      // documentElement.style.zoom rather than the engine's zoomIn/zoomOut:
      // those call the plugin's Android-only zoom APIs, which no-op on Windows.
      widget.runJs(
        'document.documentElement.style.zoom='
        '"${_pageZoom.toStringAsFixed(3)}";',
      );
    }
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _lastScale = 1.0;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _pendingDx += event.panDelta.dx;
    _pendingDy += event.panDelta.dy;

    // Pinch. Ignore imperceptible jitter so a two-finger scroll that drifts a
    // fraction of a percent doesn't slowly rescale the page.
    if ((event.scale - _lastScale).abs() > 0.01) {
      _pageZoom = (_pageZoom * (event.scale / _lastScale)).clamp(0.25, 5.0);
      _lastScale = event.scale;
      _zoomDirty = true;
    }

    _scheduleFlush();
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    _lastScale = 1.0;
    _scheduleFlush();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerPanZoomEnd: _onPanZoomEnd,
      // Translucent, not opaque: the webview underneath must keep receiving
      // clicks, text selection and mouse-wheel scroll exactly as before. This
      // widget only observes the pan-zoom stream nothing else consumes.
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
