import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';

class HibernatedTabPlaceholder extends ConsumerWidget {
  const HibernatedTabPlaceholder({super.key, required this.tab});

  final BrowserTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.read(themeProvider);
    final bg = theme.backgroundColor;
    final isLight = theme.mode == ThemeMode.light;
    final mutedColor = isLight
        ? kMiraInkPrimary.withAlpha(60)
        : Colors.white24;
    final textColor = isLight
        ? kMiraInkPrimary.withAlpha(80)
        : Colors.white30;

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
