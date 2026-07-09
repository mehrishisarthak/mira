import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/constants/app_fonts.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';

class TabsSheet extends ConsumerWidget {
  const TabsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGhostActive = ref.watch(isGhostModeProvider);

    final normalState = ref.watch(tabsProvider);
    final ghostState = ref.watch(ghostTabsProvider);

    final theme = ref.watch(themeProvider);
    final isLight = theme.mode == ThemeMode.light;
    final surface = isLight ? Colors.white : const Color(0xFF1A1A1A);
    final textColor = isLight ? kMiraInkPrimary : Colors.white;
    final accent = isGhostActive ? Colors.redAccent : theme.primaryColor;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: accent, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Content
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Ghost tabs ─────────────────────────────────────────────
                if (ghostState.tabs.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'GHOST',
                    count: ghostState.tabs.length,
                    accent: Colors.redAccent,
                    textColor: textColor,
                    onClear: () {
                      HapticFeedback.mediumImpact();
                      ref.read(ghostTabsProvider.notifier).nuke();
                    },
                    onAdd: () {
                      HapticFeedback.lightImpact();
                      ref.read(ghostTabsProvider.notifier).addTab();
                      ref.read(isGhostModeProvider.notifier).state = true;
                      Navigator.pop(context);
                    },
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _TabRow(
                          key: ValueKey(ghostState.tabs[i].id),
                          tab: ghostState.tabs[i],
                          isActive: isGhostActive &&
                              ghostState.tabs[i].id ==
                                  (ghostState.safeActiveTab?.id ?? ''),
                          isGhost: true,
                          accent: Colors.redAccent,
                          textColor: textColor,
                          surface: surface,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(isGhostModeProvider.notifier).state = true;
                            ref.read(ghostTabsProvider.notifier).switchTab(i);
                            Navigator.pop(context);
                          },
                          onClose: () {
                            HapticFeedback.lightImpact();
                            ref.read(ghostTabsProvider.notifier).closeTab(
                                ghostState.tabs[i].id);
                          },
                        ),
                        childCount: ghostState.tabs.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Divider(
                          color: textColor.withValues(alpha: 0.07), height: 1),
                    ),
                  ),
                ],

                // ── Normal tabs ────────────────────────────────────────────
                _SectionHeader(
                  label: 'TABS',
                  count: normalState.tabs.length,
                  accent: theme.primaryColor,
                  textColor: textColor,
                  onClear: normalState.tabs.length > 1
                      ? () {
                          HapticFeedback.mediumImpact();
                          ref.read(tabsProvider.notifier).nuke();
                        }
                      : null,
                  onAdd: () {
                    HapticFeedback.lightImpact();
                    ref.read(tabsProvider.notifier).addTab();
                    ref.read(isGhostModeProvider.notifier).state = false;
                    Navigator.pop(context);
                  },
                ),

                if (normalState.tabs.isEmpty ||
                    (normalState.tabs.length == 1 &&
                        normalState.tabs.first.url.isEmpty))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No open tabs',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.25),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _TabRow(
                          key: ValueKey(normalState.tabs[i].id),
                          tab: normalState.tabs[i],
                          isActive: !isGhostActive &&
                              normalState.tabs[i].id ==
                                  normalState.activeTab.id,
                          isGhost: false,
                          accent: theme.primaryColor,
                          textColor: textColor,
                          surface: surface,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(isGhostModeProvider.notifier).state =
                                false;
                            ref.read(tabsProvider.notifier).switchTab(i);
                            Navigator.pop(context);
                          },
                          onClose: () {
                            HapticFeedback.lightImpact();
                            ref.read(tabsProvider.notifier).closeTab(
                                normalState.tabs[i].id);
                          },
                        ),
                        childCount: normalState.tabs.length,
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(height: bottom + 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color accent;
  final Color textColor;
  final VoidCallback? onClear;
  final VoidCallback onAdd;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.accent,
    required this.textColor,
    required this.onClear,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
        child: Row(
          children: [
            Text(
              label,
              style: jetBrainsMono(
                fontSize: 10,
                color: accent,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            if (onClear != null)
              IconButton(
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: textColor.withValues(alpha: 0.3),
                ),
                tooltip: 'Close all',
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            IconButton(
              icon: Icon(Icons.add, size: 20, color: accent),
              tooltip: 'New tab',
              onPressed: onAdd,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab row ───────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  final BrowserTab tab;
  final bool isActive;
  final bool isGhost;
  final Color accent;
  final Color textColor;
  final Color surface;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabRow({
    super.key,
    required this.tab,
    required this.isActive,
    required this.isGhost,
    required this.accent,
    required this.textColor,
    required this.surface,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final title = tab.title.isEmpty
        ? (tab.url.isEmpty ? 'New Tab' : tab.url)
        : tab.title;
    final subtitle = tab.url.isEmpty ? 'Start page' : _cleanUrl(tab.url);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isActive
            ? accent.withValues(alpha: 0.08)
            : textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  )
                : null,
            child: Row(
              children: [
                // Favicon placeholder / ghost icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isGhost
                        ? Colors.redAccent.withValues(alpha: 0.1)
                        : accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isGhost
                        ? Icons.visibility_outlined
                        : (tab.url.isEmpty
                            ? Icons.add
                            : Icons.language),
                    size: 16,
                    color: isGhost
                        ? Colors.redAccent.withValues(alpha: 0.7)
                        : accent.withValues(alpha: 0.6),
                  ),
                ),

                const SizedBox(width: 12),

                // Title + URL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? textColor
                              : textColor.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tab.url.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.35),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Active indicator dot
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // Close button
                GestureDetector(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: textColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cleanUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}
