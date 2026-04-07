import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/skelleton_loader.dart';

/// Isolated skeleton overlay — watches [browserChromeProvider] loading progress
/// independently so that onProgressChanged callbacks only rebuild this widget.
class WebViewSkeletonOverlay extends ConsumerWidget {
  const WebViewSkeletonOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(browserChromeProvider.select((s) => s.loadingProgress));
    final activeTabUrl =
        ref.watch(currentActiveTabProvider.select((t) => t.url));
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isLoading = !isDesktop && progress < 100 && activeTabUrl.isNotEmpty;
    return IgnorePointer(
      ignoring: !isLoading,
      child: AnimatedOpacity(
        opacity: isLoading ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        child: const WebSkeletonLoader(),
      ),
    );
  }
}
