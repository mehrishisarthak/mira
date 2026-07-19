import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

/// Self-contained page-load progress bar.
///
/// Watches only `loadingProgress` (and the active URL) via `.select`, so the
/// frequent progress ticks during a page load rebuild *this widget alone* —
/// not the whole Mainscreen, which previously watched the entire
/// browserChromeProvider at its build root and re-rendered on every tick.
class BrowserProgressBar extends ConsumerWidget {
  final Color color;
  final double? minHeight;

  const BrowserProgressBar({super.key, required this.color, this.minHeight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(browserChromeProvider.select((s) => s.loadingProgress)) / 100;
    final url = ref.watch(tabsProvider.select((p) => p.safeActiveTab?.url ?? ''));

    if (progress >= 1.0 || url.isEmpty) return const SizedBox.shrink();

    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.transparent,
      color: color,
      minHeight: minHeight,
    );
  }
}




