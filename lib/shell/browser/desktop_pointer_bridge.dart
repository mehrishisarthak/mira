import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
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
/// Deltas accumulate and flush once per rendered frame via a [Ticker], not on a
/// fixed timer. A trackpad emits 60–120 updates/sec, and one
/// `evaluateJavascript` round-trip each would swamp the IPC bridge (the same
/// concern as O-70). Ticking on vsync also means one scroll write per frame
/// drawn, which is what makes it read as smooth rather than stepped.
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

class _DesktopPointerBridgeState extends State<DesktopPointerBridge>
    with SingleTickerProviderStateMixin {
  /// Raw pan deltas are small; without a multiplier a full swipe barely moves
  /// the page. Tuned to sit near Chrome on the same hardware.
  static const double _scrollMultiplier = 3.0;

  /// Scrolls the scrollable ancestor under the cursor, falling back to the
  /// document. `window.scrollBy` alone only moves the document, so any page
  /// built from inner scroll containers — which is most modern sites — ignored
  /// the gesture entirely, and horizontal scrolling never worked at all
  /// because the document itself rarely overflows sideways.
  static const String _scrollJs = '''
(function(x,y,dx,dy){
  var e=document.elementFromPoint(x,y);
  while(e&&e!==document.body&&e!==document.documentElement){
    var s=getComputedStyle(e),
        vy=s.overflowY,vx=s.overflowX,
        cy=(vy==='auto'||vy==='scroll')&&e.scrollHeight>e.clientHeight,
        cx=(vx==='auto'||vx==='scroll')&&e.scrollWidth>e.clientWidth;
    if((dy&&cy)||(dx&&cx)){
      if(cy)e.scrollTop+=dy;
      if(cx)e.scrollLeft+=dx;
      return;
    }
    e=e.parentElement;
  }
  window.scrollBy(dx,dy);
})''';

  Ticker? _ticker;
  double _pendingDx = 0;
  double _pendingDy = 0;
  Offset _cursor = Offset.zero;

  /// Cumulative scale reported since the gesture began (1.0 at start), so the
  /// per-frame zoom step is the ratio against what we last applied.
  double _lastScale = 1.0;
  double _pageZoom = 1.0;
  bool _zoomDirty = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _wake() {
    if (_ticker != null && !_ticker!.isActive) _ticker!.start();
  }

  void _onTick(Duration _) {
    if (!mounted) return;

    final dx = _pendingDx;
    final dy = _pendingDy;
    _pendingDx = 0;
    _pendingDy = 0;

    if (dx == 0 && dy == 0 && !_zoomDirty) {
      // Idle — stop ticking so we aren't burning a frame callback for the life
      // of the browser view.
      _ticker?.stop();
      return;
    }

    if (dx != 0 || dy != 0) {
      // Negated: panDelta describes how the content is dragged, while a scroll
      // offset runs the opposite way.
      final sx = (-dx * _scrollMultiplier).toStringAsFixed(2);
      final sy = (-dy * _scrollMultiplier).toStringAsFixed(2);
      widget.runJs(
        '$_scrollJs(${_cursor.dx.toStringAsFixed(0)},'
        '${_cursor.dy.toStringAsFixed(0)},$sx,$sy);',
      );
    }

    if (_zoomDirty) {
      _zoomDirty = false;
      // documentElement.style.zoom rather than BrowserEngine.zoomIn/zoomOut:
      // those call the plugin's Android-only zoom APIs, which no-op on Windows.
      widget.runJs(
        'document.documentElement.style.zoom='
        '"${_pageZoom.toStringAsFixed(3)}";',
      );
    }
  }

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.globalToLocal(global);
    return global;
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _lastScale = 1.0;
    _cursor = _toLocal(event.position);
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _cursor = _toLocal(event.position);
    _pendingDx += event.panDelta.dx;
    _pendingDy += event.panDelta.dy;

    // Pinch. Ignore imperceptible jitter so a two-finger scroll that drifts a
    // fraction of a percent doesn't slowly rescale the page.
    if ((event.scale - _lastScale).abs() > 0.01) {
      _pageZoom = (_pageZoom * (event.scale / _lastScale)).clamp(0.25, 5.0);
      _lastScale = event.scale;
      _zoomDirty = true;
    }

    _wake();
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) {
    _lastScale = 1.0;
    _wake();
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
