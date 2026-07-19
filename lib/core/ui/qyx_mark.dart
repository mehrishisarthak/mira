import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The Qyx brand mark: a ring broken at 45°, crossed by the Q tail.
///
/// Drawn with a [CustomPainter] rather than shipped as an SVG asset — the whole
/// mark is one arc plus one line, which is not worth a `flutter_svg` dependency
/// (and a painter recolours natively without a `ColorFilter`).
///
/// Deliberately monochrome: the app ships five user-selectable accents
/// ([MiraStyle]), so the mark carries no colour of its own. Pass the live accent
/// in, or let it inherit the ambient [IconTheme].
class QyxMark extends StatelessWidget {
  const QyxMark({
    super.key,
    this.size = 64,
    this.color,
    this.strokeWidth,
  });

  final double size;
  final Color? color;

  /// In mark units (the mark is authored on a 64-unit grid), scaled with [size].
  /// Defaults to a size-aware weight — a single fixed weight goes spindly small
  /// and heavy large.
  final double? strokeWidth;

  double get _defaultStroke {
    if (size <= 20) return 8.5;
    if (size <= 28) return 7.5;
    if (size <= 40) return 7.0;
    return 6.5;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _QyxMarkPainter(
          color: color ?? IconTheme.of(context).color ?? Colors.white,
          strokeWidth: strokeWidth ?? _defaultStroke,
        ),
      ),
    );
  }
}

class _QyxMarkPainter extends CustomPainter {
  const _QyxMarkPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  /// Ring gap runs 35°→55°; the arc therefore starts at 55° and sweeps the
  /// long way round (340°) back to 35°, leaving the tail room to cross.
  static const double _startAngle = 55 * math.pi / 180;
  static const double _sweepAngle = 340 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 64.0; // mark units -> logical pixels
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * u
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(32 * u, 32 * u), radius: 20 * u),
      _startAngle,
      _sweepAngle,
      false,
      paint,
    );
    canvas.drawLine(Offset(43 * u, 43 * u), Offset(56 * u, 56 * u), paint);
  }

  @override
  bool shouldRepaint(_QyxMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
