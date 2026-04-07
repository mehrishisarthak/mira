import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';

class HibernatedTabPlaceholder extends ConsumerWidget {
  const HibernatedTabPlaceholder({super.key, required this.tab});

  final BrowserTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = ref.read(themeProvider).backgroundColor;
    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, size: 40, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              tab.title.isEmpty ? 'New Tab' : tab.title,
              style: const TextStyle(color: Colors.white30, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
