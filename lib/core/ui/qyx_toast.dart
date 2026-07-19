import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qyx/constants/app_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:qyx/core/app_globals.dart';

/// Semantic tone — separate from the app's five user-selectable accent
/// themes, same as a status pill wouldn't recolour with the brand.
enum QyxToastKind { info, success, error }

/// A top-anchored, styled, self-dismissing notification.
///
/// Replaces [ScaffoldMessenger]'s [SnackBar] on mobile: a bottom-anchored
/// Material snackbar sits directly above the thumb and the tab bar, which is
/// exactly where a user's hand already is — notifications competed with
/// whatever they were about to tap next. Anchoring to the top, like Chrome's
/// and most mobile browsers' in-app notices, keeps it out of the way of both
/// hands and any bottom navigation chrome.
///
/// Driven entirely through [rootNavigatorKey] rather than a [BuildContext],
/// so it works identically from a widget's build method and from engine
/// page-event callbacks that only ever had [scaffoldMessengerKey] to work
/// with (see [in_app_webview_engine.dart], `download_service_mobile.dart`).
/// A new toast replaces whatever is currently showing rather than stacking —
/// same one-at-a-time behavior the code already had via
/// `..clearSnackBars()..showSnackBar()`.
class QyxToast {
  QyxToast._();

  static OverlayEntry? _entry;
  static GlobalKey<_QyxToastCardState>? _cardKey;
  static Timer? _timer;

  static void show(
    String message, {
    QyxToastKind kind = QyxToastKind.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlayState = rootNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _dismissCurrent(animate: false);

    final cardKey = GlobalKey<_QyxToastCardState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _QyxToastCard(
        key: cardKey,
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onAction: () {
          onAction?.call();
          _dismissCurrent(animate: true);
        },
      ),
    );

    _entry = entry;
    _cardKey = cardKey;
    overlayState.insert(entry);
    cardKey.currentState?.playIn();

    _timer = Timer(duration, () => _dismissCurrent(animate: true));
  }

  static void _dismissCurrent({required bool animate}) {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    final key = _cardKey;
    _entry = null;
    _cardKey = null;
    if (entry == null) return;

    if (animate && key?.currentState != null) {
      key!.currentState!.playOut().then((_) => entry.remove());
    } else {
      entry.remove();
    }
  }
}

class _QyxToastCard extends StatefulWidget {
  const _QyxToastCard({
    super.key,
    required this.message,
    required this.kind,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final QyxToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_QyxToastCard> createState() => _QyxToastCardState();
}

class _QyxToastCardState extends State<_QyxToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 160),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  double _dragOffset = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void playIn() => _ctrl.forward();
  Future<void> playOut() => _ctrl.reverse();

  (Color, IconData) get _tone {
    switch (widget.kind) {
      case QyxToastKind.success:
        return (Colors.greenAccent, Icons.check_circle_outline);
      case QyxToastKind.error:
        return (Colors.redAccent, Icons.error_outline);
      case QyxToastKind.info:
        return (Colors.white70, Icons.info_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (accent, icon) = _tone;
    final top = MediaQuery.of(context).padding.top + 10;

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Swipe up to dismiss — the same gesture a system notification
            // shade uses, and the natural complement to sliding in from the
            // top.
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < 0) {
                setState(() => _dragOffset += d.delta.dy);
              }
            },
            onVerticalDragEnd: (_) {
              if (_dragOffset < -24) {
                QyxToast._dismissCurrent(animate: true);
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            onTap: () => QyxToast._dismissCurrent(animate: true),
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.22), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 19, color: accent),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: jetBrainsMono(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.actionLabel != null) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: widget.onAction,
                          child: Text(
                            widget.actionLabel!,
                            style: jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Platform-aware notification entry point. Mobile (Android/iOS) shows the
/// [QyxToast] card; everywhere else keeps the existing bottom [SnackBar]
/// behavior via [scaffoldMessengerKey] untouched — this was scoped to mobile,
/// and desktop's bottom-right corner is far less obtrusive on a large window
/// than the same anchor was on a phone.
void showQyxNotice(
  String message, {
  QyxToastKind kind = QyxToastKind.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (isMobile) {
    QyxToast.show(
      message,
      kind: kind,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    return;
  }

  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}
