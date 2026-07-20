@Tags(['tool'])
library;

// One-off generator: rasterises the Qyx mark to the launcher-icon source PNGs
// so the icon is derived from QyxMark rather than hand-drawn, and cannot drift
// from what the app renders.
//
//   flutter test test/tool_generate_icon.dart
//   dart run flutter_launcher_icons
//
// Not part of the normal suite's intent — it writes files. Tagged `tool`.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qyx/core/entities/theme_entity.dart';
import 'package:qyx/core/ui/qyx_mark.dart';

const double _canvas = 1024;

/// Legacy square icon: the mark fills 60% of the canvas, leaving a margin that
/// reads as deliberate padding rather than a crop.
const double _legacyFraction = 0.60;

/// Adaptive foreground. flutter_launcher_icons wraps the foreground drawable in
/// its own `android:inset="16%"` (so the art is scaled to 68% and centred), and
/// the OEM mask then crops to the centre 72/108 ≈ 66.7%. Drawing the mark at
/// 0.60/0.68 ≈ 0.88 of this canvas lands it back at ~60% of the final icon —
/// matching the legacy icon and sitting inside the safe zone. Drawing it at
/// 0.60 here would net ~41%: a small mark adrift in a large field.
const double _foregroundFraction = 0.88;

Future<void> _render(
  WidgetTester tester, {
  required String path,
  required Color? background,
  required double markFraction,
}) async {
  final key = GlobalKey();

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: _canvas,
          height: _canvas,
          child: ColoredBox(
            color: background ?? const Color(0x00000000),
            child: Center(
              // Optical centring. QyxMark is authored in a 64-unit box with the
              // ring centred at (32,32), but the tail runs out to ~58, putting
              // the drawn bounds' centre nearer (33.5, 33.5). Geometric
              // centring therefore reads low and right — invisible in-app,
              // obvious in a launcher icon. Nudge back by the difference.
              child: Transform.translate(
                offset: Offset(
                  -_canvas * markFraction * 1.5 / 64,
                  -_canvas * markFraction * 1.5 / 64,
                ),
                child: QyxMark(
                  size: _canvas * markFraction,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  late final ui.Image image;
  late final ByteData? png;
  await tester.runAsync(() async {
    image = await boundary.toImage(pixelRatio: 1.0);
    png = await image.toByteData(format: ui.ImageByteFormat.png);
  });

  File(path).writeAsBytesSync(png!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('writes launcher icon sources', (tester) async {
    await tester.binding.setSurfaceSize(const Size(_canvas, _canvas));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Legacy square icon: mark on the brand matte black.
    await _render(
      tester,
      path: 'assets/icon.png',
      background: kMiraMatteBlack,
      markFraction: _legacyFraction,
    );

    // Adaptive foreground: mark only, transparent — the background is supplied
    // as a flat colour by flutter_launcher_icons.
    await _render(
      tester,
      path: 'assets/icon_foreground.png',
      background: null,
      markFraction: _foregroundFraction,
    );

    expect(File('assets/icon.png').lengthSync(), greaterThan(0));
    expect(File('assets/icon_foreground.png').lengthSync(), greaterThan(0));
  });
}
