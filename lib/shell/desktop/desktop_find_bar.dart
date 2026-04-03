import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

/// Chrome-style persistent find bar for desktop window layouts.
class DesktopFindBar extends ConsumerStatefulWidget {
  const DesktopFindBar({super.key});

  @override
  ConsumerState<DesktopFindBar> createState() => _DesktopFindBarState();
}

class _DesktopFindBarState extends ConsumerState<DesktopFindBar> {
  late final TextEditingController _query;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    ref.read(desktopFindBarVisibleProvider.notifier).state = false;
    _query.clear();
    final find = ref.read(activeFindInteractionProvider);
    if (find != null) {
      unawaited(find.clearMatches());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final find = ref.watch(activeFindInteractionProvider);
    final isLight = theme.mode == ThemeMode.light;
    final bg = theme.surfaceColor;
    final fg = isLight ? kMiraInkPrimary : Colors.white;
    final muted = isLight ? kMiraInkMuted : Colors.white54;
    final accent = theme.primaryColor;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Material(
        elevation: 6,
        color: bg,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: accent.withValues(alpha: 0.35)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _query,
                  focusNode: _focus,
                  autofocus: true,
                  style: TextStyle(color: fg, fontSize: 14),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText:
                        find == null ? 'No page to search' : 'Find in page…',
                    hintStyle: TextStyle(color: muted, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  enabled: find != null,
                  onChanged: (t) async {
                    if (find == null) return;
                    if (t.isEmpty) {
                      await find.clearMatches();
                    } else {
                      await find.findAll(find: t);
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: find == null
                    ? null
                    : () async {
                        await find.findNext(forward: false);
                      },
                icon: Icon(Icons.keyboard_arrow_up, color: fg, size: 22),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: find == null
                    ? null
                    : () async {
                        await find.findNext(forward: true);
                      },
                icon: Icon(Icons.keyboard_arrow_down, color: fg, size: 22),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _close,
                icon: Icon(Icons.close, color: muted, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
