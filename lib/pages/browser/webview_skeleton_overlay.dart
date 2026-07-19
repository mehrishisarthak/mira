import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/pages/browser_chrome_providers.dart';
import 'package:qyx/pages/skeleton_loader.dart';

/// Isolated skeleton overlay — watches [browserChromeProvider] loading progress
/// independently so that onProgressChanged callbacks only rebuild this widget.
class WebViewSkeletonOverlay extends ConsumerWidget {
  const WebViewSkeletonOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(browserChromeProvider.select((s) => s.loadingProgress));
    final activeTabUrl =
        ref.watch(tabsProvider.select((p) => p.safeActiveTab?.url ?? ''));
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isLoading = !isDesktop && progress < 100 && activeTabUrl.isNotEmpty;
    return IgnorePointer(
      ignoring: !isLoading,
      child: AnimatedOpacity(
        opacity: isLoading ? 1.0 : 0.0,
        duration: Duration(milliseconds: isLoading ? 150 : 400),
        curve: Curves.easeInOut,
        // Pause the shimmer's ticker when not loading. The loader stays mounted
        // (faded to 0), so without this its controller repaints ~60fps for the
        // life of the browser view, behind the page — stealing frames from
        // other app animations.
        child: TickerMode(
          enabled: isLoading,
          child: const WebSkeletonLoader(),
        ),
      ),
    );
  }
}




