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
/// Deltas accumulate and flush once per rendered frame via a [Ticker], vsync-
/// aligned rather than clock-driven. Sends are additionally capped to one
/// outstanding [runJs] call at a time — see [_inflight] for why that is not
/// optional.
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

  /// Fraction of the raw pinch gesture that reaches the page. At 1:1 a small,
  /// ordinary pinch overshot the intended zoom level — trackpad scale deltas
  /// are more sensitive than they feel. Tunable; this is a starting point, not
  /// a measured value.
  static const double _zoomSensitivity = 0.45;

  /// Zooming a page below 100% mostly happens by accident mid-gesture and
  /// rarely helps — there's no more content to reveal, just shrinking text —
  /// so it's excluded rather than merely discouraged.
  static const double _minZoom = 1.0;

  /// Comfortable reading ceiling. Also caps how expensive the worst-case
  /// relayout in [_onTick] can be — style.zoom relayouts a fully-scaled page,
  /// and an unbounded max made both the visual result and the reflow cost
  /// worse together.
  static const double _maxZoom = 2.5;

  /// Resolves scroll per axis independently, then applies each.
  ///
  /// The previous version resolved both axes through one scrollable ancestor
  /// and returned as soon as it found one — so a vertical-only container
  /// (near-universal; almost every page has one) silently absorbed the whole
  /// call and the horizontal delta was dropped without ever reaching the
  /// window.scrollBy fallback. A real trackpad pan is essentially never
  /// axis-pure — a "horizontal" swipe still carries a small residual vertical
  /// delta — so that shadowing fired on almost every gesture, which is why
  /// left/right pan looked entirely broken rather than just occasionally off.
  static const String _scrollJs = '''
(function(x,y,dx,dy){
  function findScrollable(el,axis){
    while(el&&el!==document.body&&el!==document.documentElement){
      var s=getComputedStyle(el);
      if(axis==='y'){
        var oy=s.overflowY;
        if((oy==='auto'||oy==='scroll')&&el.scrollHeight>el.clientHeight){return el;}
      } else {
        var ox=s.overflowX;
        if((ox==='auto'||ox==='scroll')&&el.scrollWidth>el.clientWidth){return el;}
      }
      el=el.parentElement;
    }
    return null;
  }
  var start=document.elementFromPoint(x,y);
  if(dy){
    var vy=findScrollable(start,'y');
    if(vy){vy.scrollTop+=dy;}else{window.scrollBy(0,dy);}
  }
  if(dx){
    var vx=findScrollable(start,'x');
    if(vx){vx.scrollLeft+=dx;}else{window.scrollBy(dx,0);}
  }
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

  /// True while a previous [runJs] call from this bridge hasn't resolved yet.
  ///
  /// This is the fix for zoom finishing 2-3 seconds after the gesture ends.
  /// The ticker fires at up to ~120Hz for a fast trackpad, and each `runJs` is
  /// a full IPC round-trip into WebView2's JS engine — worse, the zoom call
  /// sets `style.zoom`, which forces a full-page relayout on every single set.
  /// With no guard, a 1-2s pinch queued 100+ unawaited calls, each doing a
  /// full reflow, and the browser kept draining that backlog long after your
  /// fingers left the trackpad — the actual "2-3 second lag." Capping
  /// outstanding calls to one bounds the worst case to a single call still in
  /// flight. Deltas keep accumulating on skipped ticks, so nothing is lost —
  /// the next call once the previous resolves just carries more.
  bool _inflight = false;

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
    if (_inflight) return; // let the outstanding call drain first

    final hasScroll = _pendingDx != 0 || _pendingDy != 0;
    if (!hasScroll && !_zoomDirty) {
      // Idle — stop ticking so we aren't burning a frame callback for the
      // life of the browser view.
      _ticker?.stop();
      return;
    }

    final dx = _pendingDx;
    final dy = _pendingDy;
    _pendingDx = 0;
    _pendingDy = 0;
    final applyZoom = _zoomDirty;
    _zoomDirty = false;

    // One combined call, not one per effect: each is a full IPC round-trip,
    // so folding scroll+zoom together halves the exposure that made the
    // backlog above possible in the first place.
    final js = StringBuffer();
    if (hasScroll) {
      // Negated: panDelta describes how the content is dragged, while a
      // scroll offset runs the opposite way.
      final sx = (-dx * _scrollMultiplier).toStringAsFixed(2);
      final sy = (-dy * _scrollMultiplier).toStringAsFixed(2);
      js.write(
        '$_scrollJs(${_cursor.dx.toStringAsFixed(0)},'
        '${_cursor.dy.toStringAsFixed(0)},$sx,$sy);',
      );
    }
    if (applyZoom) {
      // documentElement.style.zoom rather than BrowserEngine.zoomIn/zoomOut:
      // those call the plugin's Android-only zoom APIs, which no-op on
      // Windows.
      js.write(
        'document.documentElement.style.zoom='
        '"${_pageZoom.toStringAsFixed(3)}";',
      );
    }

    _inflight = true;
    widget.runJs(js.toString()).whenComplete(() => _inflight = false);
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
      final rawRatio = event.scale / _lastScale;
      final dampedRatio = 1 + (rawRatio - 1) * _zoomSensitivity;
      _pageZoom = (_pageZoom * dampedRatio).clamp(_minZoom, _maxZoom);
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
