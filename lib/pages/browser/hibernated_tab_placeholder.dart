import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

class HibernatedTabPlaceholder extends ConsumerWidget {
  const HibernatedTabPlaceholder({super.key, required this.tab, this.snapshot});

  final BrowserTab tab;
  final TabSnapshotData? snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final bg = theme.backgroundColor;
    final isLight = theme.mode == ThemeMode.light;
    final mutedColor = isLight
        ? kMiraInkPrimary.withAlpha(60)
        : Colors.white24;
    final textColor = isLight
        ? kMiraInkPrimary.withAlpha(80)
        : Colors.white30;

    if (snapshot != null) {
      Widget? imageWidget;
      if (snapshot!.bytes != null) {
        imageWidget = Image.memory(
          snapshot!.bytes!,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          cacheWidth: 400,
        );
      } else if (snapshot!.diskPath != null) {
        imageWidget = Image.file(
          File(snapshot!.diskPath!),
          fit: BoxFit.fill,
          gaplessPlayback: true,
          cacheWidth: 400,
          errorBuilder: (context, error, stackTrace) => _buildFallback(bg, mutedColor, textColor),
        );
      }

      if (imageWidget != null) {
        return Container(
          color: bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              // Semi-transparent overlay to indicate it's paused/hibernated
              Container(color: Colors.black.withOpacity(0.2)),
              const Center(
                child: Icon(Icons.refresh_rounded, size: 48, color: Colors.white70),
              ),
            ],
          ),
        );
      }
    }

    return _buildFallback(bg, mutedColor, textColor);
  }

  Widget _buildFallback(Color bg, Color mutedColor, Color textColor) {
    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 40, color: mutedColor),
            const SizedBox(height: 12),
            Text(
              tab.title.isEmpty ? 'New Tab' : tab.title,
              style: TextStyle(color: textColor, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
