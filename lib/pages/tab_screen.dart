import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/constants/app_fonts.dart';

import 'package:qyx/core/entities/tab_entity.dart';
import 'package:qyx/core/entities/theme_entity.dart';
import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/core/notifiers/theme_notifier.dart';
import 'package:qyx/pages/browser_chrome_providers.dart';

class TabsSheet extends ConsumerWidget {
  const TabsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGhostActive = ref.watch(isGhostModeProvider);

    final normalState = ref.watch(tabsProvider);
    final ghostState = ref.watch(ghostTabsProvider);

    final theme = ref.watch(themeProvider);
    final isLight = theme.mode == ThemeMode.light;
    final surface = isLight ? const Color(0xFFF2F2F7) : const Color(0xFF121212);
    final textColor = isLight ? kMiraInkPrimary : Colors.white;
    final bottom = MediaQuery.of(context).padding.bottom;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: top + 16)),
          // ── Ghost tabs ─────────────────────────────────────────────
          if (ghostState.tabs.isNotEmpty) ...[
            _SectionHeader(
              label: 'GHOST',
              count: ghostState.tabOrder.length,
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
              onDone: isGhostActive ? () => Navigator.pop(context) : null,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TabGridCard(
                    key: ValueKey(ghostState.tabs[ghostState.tabOrder[i]]!.id),
                    tab: ghostState.tabs[ghostState.tabOrder[i]]!,
                    isActive: isGhostActive &&
                        ghostState.tabs[ghostState.tabOrder[i]]!.id ==
                            (ghostState.safeActiveTab?.id ?? ''),
                    isGhost: true,
                    accent: Colors.redAccent,
                    textColor: textColor,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(isGhostModeProvider.notifier).state = true;
                      ref.read(ghostTabsProvider.notifier).switchTabById(
                          ghostState.tabs[ghostState.tabOrder[i]]!.id);
                      Navigator.pop(context);
                    },
                    onClose: () {
                      HapticFeedback.lightImpact();
                      ref.read(ghostTabsProvider.notifier).closeTab(ghostState.tabs[ghostState.tabOrder[i]]!.id);
                    },
                  ),
                  childCount: ghostState.tabOrder.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Divider(color: textColor.withValues(alpha: 0.07), height: 1),
              ),
            ),
          ],

          // ── Normal tabs ────────────────────────────────────────────
          _SectionHeader(
            label: 'TABS',
            count: normalState.tabOrder.length,
            accent: theme.primaryColor,
            textColor: textColor,
            onClear: normalState.tabOrder.length > 1
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
            onDone: !isGhostActive ? () => Navigator.pop(context) : null,
          ),

          if (normalState.tabs.isEmpty ||
              (normalState.tabOrder.length == 1 && normalState.tabs[normalState.tabOrder.first]!.url.isEmpty))
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
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TabGridCard(
                    key: ValueKey(normalState.tabs[normalState.tabOrder[i]]!.id),
                    tab: normalState.tabs[normalState.tabOrder[i]]!,
                    isActive: !isGhostActive &&
                        normalState.tabs[normalState.tabOrder[i]]!.id == normalState.safeActiveTab?.id,
                    isGhost: false,
                    accent: theme.primaryColor,
                    textColor: textColor,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(isGhostModeProvider.notifier).state = false;
                      ref.read(tabsProvider.notifier).switchTabById(
                          normalState.tabs[normalState.tabOrder[i]]!.id);
                      Navigator.pop(context);
                    },
                    onClose: () {
                      HapticFeedback.lightImpact();
                      ref.read(tabsProvider.notifier).closeTab(normalState.tabs[normalState.tabOrder[i]]!.id);
                    },
                  ),
                  childCount: normalState.tabOrder.length,
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(height: bottom + 24),
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
  final VoidCallback? onDone;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.accent,
    required this.textColor,
    required this.onClear,
    required this.onAdd,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
        child: Row(
          children: [
            Text(
              label,
              style: jetBrainsMono(
                fontSize: 11,
                color: accent,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w700,
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
                  size: 20,
                  color: textColor.withValues(alpha: 0.3),
                ),
                tooltip: 'Close all',
                onPressed: onClear,
              ),
            IconButton(
              icon: Icon(Icons.add, size: 22, color: accent),
              tooltip: 'New tab',
              onPressed: onAdd,
            ),
            if (onDone != null)
              TextButton(
                onPressed: onDone,
                child: Text('Done', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Grid Card ────────────────────────────────────────────────────────────

class _TabGridCard extends ConsumerWidget {
  final BrowserTab tab;
  final bool isActive;
  final bool isGhost;
  final Color accent;
  final Color textColor;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabGridCard({
    super.key,
    required this.tab,
    required this.isActive,
    required this.isGhost,
    required this.accent,
    required this.textColor,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = tab.title.isEmpty ? (tab.url.isEmpty ? 'New Tab' : tab.url) : tab.title;
    final snapshotData = ref.watch(tabSnapshotCacheProvider)[tab.id];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: accent, width: 2) : Border.all(color: textColor.withValues(alpha: 0.1), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header (Chrome style)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: isGhost 
                  ? const Color(0xFF1F1F1F) 
                  : (textColor == Colors.white ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5)),
              child: Row(
                children: [
                  Icon(
                    isGhost ? Icons.visibility_outlined : (tab.url.isEmpty ? Icons.add : Icons.language), 
                    size: 16, 
                    color: isGhost ? Colors.redAccent : accent
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12, 
                        color: textColor.withValues(alpha: 0.8), 
                        fontWeight: FontWeight.w600
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close, size: 16, color: textColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
            // Snapshot
            Expanded(
              child: SizedBox.expand(
                child: snapshotData == null 
                  ? _buildPlaceholder()
                  : (snapshotData.bytes != null) 
                    ? Image.memory(
                        snapshotData.bytes!, 
                        fit: BoxFit.cover, 
                        cacheWidth: 400,
                      )
                    : (snapshotData.diskPath != null)
                      ? Image.file(
                          File(snapshotData.diskPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: textColor.withValues(alpha: 0.02),
      child: Center(
        child: Icon(
          isGhost ? Icons.visibility_outlined : Icons.public, 
          size: 32, 
          color: textColor.withValues(alpha: 0.1)
        ),
      ),
    );
  }
}


