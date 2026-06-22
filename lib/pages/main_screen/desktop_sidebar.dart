import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/entities/theme_entity.dart' show MiraTheme, kMiraInkPrimary;
import 'package:mira/pages/downloads_screen.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/main_screen/desktop_browser_chrome.dart' show showDesktopMiraMenuPopup;

final desktopSidebarExpandedProvider = StateProvider<bool>((ref) => true);

class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(desktopSidebarExpandedProvider);
    final isGhost = ref.watch(isGhostModeProvider);
    final theme = ref.watch(themeProvider);
    final tabState = ref.watch(tabsProvider);
    final ghostState = ref.watch(ghostTabsProvider);
    final normalTabs = tabState.tabs;
    final normalActive = tabState.activeIndex;
    final ghostTabs = ghostState.tabs;
    final ghostActive = ghostState.activeIndex;

    final isLight = theme.mode == ThemeMode.light;
    final bg = isGhost ? const Color(0xFF0F0A0A) : theme.surfaceColor;
    final fg = (isLight && !isGhost) ? kMiraInkPrimary : Colors.white;
    final muted = fg.withValues(alpha: 0.4);
    final border = isGhost
        ? Colors.redAccent.withValues(alpha: 0.2)
        : fg.withValues(alpha: 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: expanded ? 240 : 52,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border)),
      ),
      // LayoutBuilder drives child layout from actual rendered width so the
      // expanded/collapsed switch happens mid-animation without overflow.
      child: LayoutBuilder(
        builder: (_, constraints) {
          final isExpanded = constraints.maxWidth > 120;
          return Column(
            children: [
              _SidebarHeader(expanded: isExpanded, isGhost: isGhost, fg: fg, theme: theme),
              const SizedBox(height: 4),
              _NewTabButton(expanded: isExpanded, isGhost: isGhost, theme: theme, fg: fg),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    if (normalTabs.isNotEmpty) ...[
                      if (isExpanded && ghostTabs.isNotEmpty)
                        _SectionLabel(label: 'TABS', color: muted),
                      ...normalTabs.asMap().entries.map((e) => _SidebarTabItem(
                        tab: e.value,
                        index: e.key,
                        isGhost: false,
                        isActive: !isGhost && e.key == normalActive,
                        expanded: isExpanded,
                        accent: theme.primaryColor,
                        fg: fg,
                        muted: muted,
                      )),
                    ],
                    if (ghostTabs.isNotEmpty) ...[
                      if (isExpanded)
                        _SectionLabel(
                          label: 'GHOST',
                          color: Colors.redAccent.withValues(alpha: 0.7),
                        )
                      else
                        Divider(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          height: 12,
                          indent: 8,
                          endIndent: 8,
                        ),
                      ...ghostTabs.asMap().entries.map((e) => _SidebarTabItem(
                        tab: e.value,
                        index: e.key,
                        isGhost: true,
                        isActive: isGhost && e.key == ghostActive,
                        expanded: isExpanded,
                        accent: Colors.redAccent,
                        fg: fg,
                        muted: muted,
                      )),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: fg.withValues(alpha: 0.08)),
              _BottomNav(
                expanded: isExpanded,
                isGhost: isGhost,
                fg: fg,
                muted: muted,
                accent: isGhost ? Colors.redAccent : theme.primaryColor,
                context: context,
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _SidebarHeader extends ConsumerWidget {
  final bool expanded;
  final bool isGhost;
  final Color fg;
  final MiraTheme theme;

  const _SidebarHeader({
    required this.expanded,
    required this.isGhost,
    required this.fg,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Constrained to 40px so it fits inside the 52px collapsed rail without the
    // default IconButton 48px min-size blowing past the available width.
    final toggleButton = IconButton(
      icon: Icon(
        expanded ? Icons.chevron_left : Icons.chevron_right,
        color: fg.withValues(alpha: 0.5),
        size: 20,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      tooltip: expanded ? 'Collapse sidebar' : 'Expand sidebar',
      onPressed: () {
        ref.read(desktopSidebarExpandedProvider.notifier).state = !expanded;
      },
    );

    if (!expanded) {
      // Collapsed: a single centered toggle, no outer padding/Spacer competing
      // for width — that competition was the RenderFlex overflow.
      return SizedBox(height: 44, child: Center(child: toggleButton));
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: isGhost
                ? const Icon(Icons.privacy_tip, color: Colors.redAccent, size: 18)
                : Icon(Icons.language, color: theme.primaryColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isGhost ? 'GHOST MODE' : 'MIRA',
              style: GoogleFonts.jetBrainsMono(
                color: isGhost ? Colors.redAccent : fg,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          toggleButton,
        ],
      ),
    );
  }
}

// ── New tab button ─────────────────────────────────────────────────────────────

class _NewTabButton extends ConsumerWidget {
  final bool expanded;
  final bool isGhost;
  final MiraTheme theme;
  final Color fg;

  const _NewTabButton({
    required this.expanded,
    required this.isGhost,
    required this.theme,
    required this.fg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = isGhost ? Colors.redAccent : theme.primaryColor;

    void onTap() {
      if (isGhost) {
        ref.read(ghostTabsProvider.notifier).addTab();
      } else {
        ref.read(tabsProvider.notifier).addTab();
      }
    }

    if (!expanded) {
      return IconButton(
        icon: Icon(Icons.add, color: accent, size: 20),
        tooltip: 'New tab',
        onPressed: onTap,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.add, color: accent, size: 16),
              const SizedBox(width: 8),
              Text(
                isGhost ? 'New ghost tab' : 'New tab',
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ── Tab item ───────────────────────────────────────────────────────────────────

class _SidebarTabItem extends ConsumerStatefulWidget {
  final BrowserTab tab;
  final int index;
  final bool isGhost;
  final bool isActive;
  final bool expanded;
  final Color accent;
  final Color fg;
  final Color muted;

  const _SidebarTabItem({
    required this.tab,
    required this.index,
    required this.isGhost,
    required this.isActive,
    required this.expanded,
    required this.accent,
    required this.fg,
    required this.muted,
  });

  @override
  ConsumerState<_SidebarTabItem> createState() => _SidebarTabItemState();
}

class _SidebarTabItemState extends ConsumerState<_SidebarTabItem> {
  bool _hovered = false;

  void _onTap() {
    ref.read(isGhostModeProvider.notifier).state = widget.isGhost;
    if (widget.isGhost) {
      ref.read(ghostTabsProvider.notifier).switchTab(widget.index);
    } else {
      ref.read(tabsProvider.notifier).switchTab(widget.index);
    }
  }

  void _onClose() {
    if (widget.isGhost) {
      ref.read(ghostTabsProvider.notifier).closeTab(widget.tab.id);
    } else {
      ref.read(tabsProvider.notifier).closeTab(widget.tab.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.tab.title.isEmpty
        ? (widget.isGhost ? 'Ghost Tab' : 'New Tab')
        : widget.tab.title;

    if (!widget.expanded) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _onTap,
          child: Container(
            height: 36,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? widget.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                widget.isGhost ? Icons.privacy_tip_outlined : Icons.tab_outlined,
                size: 16,
                color: widget.isActive
                    ? widget.accent
                    : widget.muted,
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.accent.withValues(alpha: 0.14)
                : (_hovered ? widget.fg.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
            border: widget.isActive
                ? Border.all(color: widget.accent.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.isGhost ? Icons.privacy_tip_outlined : Icons.tab_outlined,
                size: 14,
                color: widget.isActive ? widget.accent : widget.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    color: widget.isActive ? widget.fg : widget.muted,
                    fontSize: 12,
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_hovered)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14, color: widget.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom nav ─────────────────────────────────────────────────────────────────

class _BottomNav extends ConsumerWidget {
  final bool expanded;
  final bool isGhost;
  final Color fg;
  final Color muted;
  final Color accent;
  final BuildContext context;

  const _BottomNav({
    required this.expanded,
    required this.isGhost,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.context,
  });

  void _toggleGhost(WidgetRef ref) {
    if (isGhost) {
      ref.read(isGhostModeProvider.notifier).state = false;
    } else {
      if (ref.read(ghostTabsProvider).tabs.isEmpty) {
        ref.read(ghostTabsProvider.notifier).addTab();
      }
      ref.read(isGhostModeProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    return Column(
      children: [
        _NavItem(
          icon: isGhost ? Icons.visibility : Icons.visibility_outlined,
          label: 'Ghost Mode',
          color: isGhost ? Colors.redAccent : muted,
          expanded: expanded,
          onTap: () => _toggleGhost(ref),
        ),
        _NavItem(
          icon: Icons.history,
          label: 'History',
          color: muted,
          expanded: expanded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoryPage()),
          ),
        ),
        _NavItem(
          icon: Icons.download_outlined,
          label: 'Downloads',
          color: muted,
          expanded: expanded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DownloadsPage()),
          ),
        ),
        _NavItem(
          icon: Icons.more_horiz,
          label: 'Settings',
          color: muted,
          expanded: expanded,
          onTap: () => showDesktopMiraMenuPopup(context),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: label,
        onPressed: onTap,
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
