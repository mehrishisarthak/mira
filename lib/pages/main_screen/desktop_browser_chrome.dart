import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/bookmarks_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/mira_drawer.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';

Future<void> showDesktopMiraMenuPopup(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 72, right: 12),
          child: Material(
            elevation: 18,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 380,
              height: (size.height - 96).clamp(420.0, 780.0),
              child: const MiraMenuPage(desktopOverlay: true),
            ),
          ),
        ),
      );
    },
  );
}

Widget buildDesktopMainTabChip({
  required WidgetRef ref,
  required BrowserTab tab,
  required int stackIndex,
  required bool tabIsGhost,
  required Color tabAccent,
  required bool showClose,
  required BrowserTab activeTab,
  required bool sessionIsGhost,
  required Color contentColor,
}) {
  final isActive = tab.id == activeTab.id && tabIsGhost == sessionIsGhost;
  final idleBorder = tabIsGhost
      ? Border.all(color: Colors.redAccent.withValues(alpha: 0.35))
      : null;

  return Listener(
    behavior: HitTestBehavior.deferToChild,
    onPointerDown: (PointerDownEvent e) {
      if (e.kind != PointerDeviceKind.mouse) return;
      if ((e.buttons & kMiddleMouseButton) == 0) return;
      if (!showClose) return;
      if (tabIsGhost) {
        ref.read(ghostTabsProvider.notifier).closeTab(tab.id);
      } else {
        ref.read(tabsProvider.notifier).closeTab(tab.id);
      }
    },
    child: GestureDetector(
      onTap: () {
        ref.read(isGhostModeProvider.notifier).state = tabIsGhost;
        if (tabIsGhost) {
          ref.read(ghostTabsProvider.notifier).switchTab(stackIndex);
        } else {
          ref.read(tabsProvider.notifier).switchTab(stackIndex);
        }
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? tabAccent.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: tabAccent.withValues(alpha: 0.65), width: 1.5)
              : idleBorder,
        ),
        child: Row(
          children: [
            if (tabIsGhost)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  size: 14,
                  color: Colors.redAccent.withValues(alpha: isActive ? 1 : 0.65),
                ),
              ),
            Expanded(
              child: Text(
                tab.title.isEmpty
                    ? (tabIsGhost ? "Ghost Tab" : "New Tab")
                    : tab.title,
                style: GoogleFonts.jetBrainsMono(
                  color: contentColor,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showClose)
              GestureDetector(
                onTap: () {
                  if (tabIsGhost) {
                    ref.read(ghostTabsProvider.notifier).closeTab(tab.id);
                  } else {
                    ref.read(tabsProvider.notifier).closeTab(tab.id);
                  }
                },
                child: Icon(Icons.close,
                    size: 14, color: contentColor.withValues(alpha: 0.5)),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget buildDesktopMainChrome({
  required BuildContext context,
  required WidgetRef ref,
  required Color bgColor,
  required Color contentColor,
  required Color accentColor,
  required List<BrowserTab> normalTabs,
  required List<BrowserTab> ghostTabs,
  required BrowserTab activeTab,
  required bool isGhost,
  required Color themePrimary,
  required IconData securityIcon,
  required Color securityColor,
  required Color hintColor,
  required bool isBookmarked,
  required double progress,
  required bool hasWebView,
  required ScrollController? tabScrollController,
  required TextEditingController urlController,
  required FocusNode urlFocusNode,
  required void Function(String) onUrlSubmitted,
}) {
  return Container(
    color: bgColor,
    child: Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Listener(
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent) {
                      final c = tabScrollController;
                      if (c != null && c.hasClients) {
                        final delta = signal.scrollDelta.dx != 0
                            ? signal.scrollDelta.dx
                            : signal.scrollDelta.dy;
                        final next = (c.offset + delta)
                            .clamp(0.0, c.position.maxScrollExtent);
                        c.animateTo(
                          next,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    }
                  },
                  child: SingleChildScrollView(
                    controller: tabScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (normalTabs.isNotEmpty)
                          ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: true,
                            itemExtent: 212,
                            itemCount: normalTabs.length,
                            onReorder: (oldIndex, newIndex) => ref
                                .read(tabsProvider.notifier)
                                .reorderTab(oldIndex, newIndex),
                            itemBuilder: (context, i) {
                              final tab = normalTabs[i];
                              return KeyedSubtree(
                                key: ValueKey<String>('n-${tab.id}'),
                                child: buildDesktopMainTabChip(
                                  ref: ref,
                                  tab: tab,
                                  stackIndex: i,
                                  tabIsGhost: false,
                                  tabAccent: themePrimary,
                                  showClose: normalTabs.length > 1,
                                  activeTab: activeTab,
                                  sessionIsGhost: isGhost,
                                  contentColor: contentColor,
                                ),
                              );
                            },
                          ),
                        if (normalTabs.isNotEmpty && ghostTabs.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 1,
                            height: 22,
                            color: contentColor.withValues(alpha: 0.2),
                          ),
                        if (ghostTabs.isNotEmpty)
                          ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: true,
                            itemExtent: 212,
                            itemCount: ghostTabs.length,
                            onReorder: (oldIndex, newIndex) => ref
                                .read(ghostTabsProvider.notifier)
                                .reorderTab(oldIndex, newIndex),
                            itemBuilder: (context, i) {
                              final tab = ghostTabs[i];
                              return KeyedSubtree(
                                key: ValueKey<String>('g-${tab.id}'),
                                child: buildDesktopMainTabChip(
                                  ref: ref,
                                  tab: tab,
                                  stackIndex: i,
                                  tabIsGhost: true,
                                  tabAccent: Colors.redAccent,
                                  showClose: ghostTabs.length > 1,
                                  activeTab: activeTab,
                                  sessionIsGhost: isGhost,
                                  contentColor: contentColor,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'New tab',
                icon: Icon(Icons.add, color: contentColor, size: 20),
                onPressed: () {
                  ref.read(tabsProvider.notifier).addTab();
                  ref.read(isGhostModeProvider.notifier).state = false;
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: contentColor, size: 20),
                tooltip: 'Back',
                onPressed: hasWebView
                    ? () => ref.read(browserChromeProvider).controller?.goBack()
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward, color: contentColor, size: 20),
                tooltip: 'Forward',
                onPressed: hasWebView
                    ? () =>
                        ref.read(browserChromeProvider).controller?.goForward()
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: contentColor, size: 20),
                tooltip: 'Reload',
                onPressed: hasWebView
                    ? () => ref.read(browserChromeProvider).controller?.reload()
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: contentColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Tooltip(
                        message: activeTab.url.isEmpty
                            ? 'Site info'
                            : 'Connection & site info',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: activeTab.url.isEmpty
                              ? null
                              : () => showSecurityDialogForUrl(
                                    context,
                                    ref,
                                    activeTab.url,
                                    securityColor,
                                    contentColor,
                                  ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(securityIcon,
                                color: securityColor, size: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: urlController,
                          focusNode: urlFocusNode,
                          style: GoogleFonts.jetBrainsMono(
                              color: contentColor, fontSize: 13),
                          cursorColor: accentColor,
                          decoration: InputDecoration(
                            hintText: isGhost
                                ? 'Ghost Mode Active'
                                : 'Search or enter address',
                            border: InputBorder.none,
                            isDense: true,
                            hintStyle: GoogleFonts.jetBrainsMono(
                                color: hintColor, fontSize: 13),
                          ),
                          onSubmitted: onUrlSubmitted,
                        ),
                      ),
                      if (activeTab.url.isNotEmpty && !isGhost)
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                              isBookmarked ? Icons.star : Icons.star_border,
                              color: isBookmarked
                                  ? Colors.yellowAccent
                                  : hintColor,
                              size: 18),
                          onPressed: () => ref
                              .read(bookmarksProvider.notifier)
                              .toggleBookmark(activeTab.url, activeTab.title),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.more_vert, color: contentColor, size: 20),
                onPressed: () => showDesktopMiraMenuPopup(context),
              ),
            ],
          ),
        ),
        if (progress < 1.0 && activeTab.url.isNotEmpty)
          LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              color: accentColor,
              minHeight: 2),
      ],
    ),
  );
}
