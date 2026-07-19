import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import '../branding_screen.dart';
import '../custom_error_screen.dart';
import 'hibernated_tab_placeholder.dart';
import 'browser_side_effects.dart';
import 'webview_skeleton_overlay.dart';

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      syncInitialEngine(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);
    registerBrowserViewSideEffects(ref: ref);

    // Rebuild only on STRUCTURAL change — add/remove/switch, the
    // branding<->webview flip (a tab's url emptying/filling), and webError
    // show/hide. A url/title/canGoBack tick during load must NOT rebuild this
    // Stack: each webview is keyed by tabId and reads initialUrl once at
    // creation, so a plain url change is invisible here (D-29 / O-80).
    String tabsSignature(NormalizedTabsState s) =>
        '${s.activeIndex}|${s.tabOrder.map((id) {
          final t = s.tabs[id]!;
          return '$id:${t.url.isEmpty}:${t.webError}';
        }).join(',')}';
    ref.watch(tabsProvider.select(tabsSignature));
    ref.watch(ghostTabsProvider.select(tabsSignature));
    final normalState = ref.read(tabsProvider);
    final ghostState = ref.read(ghostTabsProvider);

    final normalTabsMap = normalState.tabs;
    final normalOrder = normalState.tabOrder;
    final normalActiveIndex = normalState.activeIndex;
    
    final ghostTabsMap = ghostState.tabs;
    final ghostOrder = ghostState.tabOrder;
    final ghostActiveIndex = ghostState.activeIndex;
    
    final awakeTabIds = ref.watch(hibernationProvider);
    final webViewSnapshot = ref.watch(webViewSnapshotProvider);

    final activeUrl = isGhost
       ? (ghostOrder.isNotEmpty ? ghostTabsMap[ghostOrder[ghostActiveIndex]]!.url : '')
        : (normalOrder.isNotEmpty ? normalTabsMap[normalOrder[normalActiveIndex]]!.url : '');
        
    final activeTabWebError = isGhost
       ? (ghostOrder.isNotEmpty ? ghostTabsMap[ghostOrder[ghostActiveIndex]]!.webError : null)
        : (normalOrder.isNotEmpty ? normalTabsMap[normalOrder[normalActiveIndex]]!.webError : null);

    return Stack(
      children: [
        ...[
         ...normalOrder.asMap().entries.map((e) => MapEntry(e.key, {'tab': normalTabsMap[e.value]!, 'isGhost': false})),
         ...ghostOrder.asMap().entries.map((e) => MapEntry(e.key, {'tab': ghostTabsMap[e.value]!, 'isGhost': true}))
        ].map((entry) {
          final index = entry.key;
          final tabData = entry.value;
          final tab = tabData['tab'] as BrowserTab;
          final isTabGhost = tabData['isGhost'] as bool;
          final isActiveMode = isTabGhost == isGhost;
          final isShowing = isActiveMode && index == (isTabGhost ? ghostActiveIndex : normalActiveIndex);

          if (tab.url.isEmpty) {
            return Positioned.fill(
              key: ValueKey('brand_${tab.id}'),
              child: Visibility(
                visible: isShowing,
                maintainState: true,
                child: const BrandingScreen(),
              ),
            );
          }

          if (!awakeTabIds.contains(tab.id)) {
            // Read the SAME snapshot cache the Tab Grid uses (tab_screen.dart) —
            // populated event-driven when a tab loses focus (mainscreen switch
            // listener) or on Tab-Grid tap (mobile app bar), both masked by an
            // animation. No background timer, no extra GPU readback: the readback
            // already happened at the transition. Scoped by tab id so a capture
            // for one tab doesn't rebuild the whole Stack (O-82).
            final cachedSnapshot =
                ref.watch(tabSnapshotCacheProvider.select((m) => m[tab.id]));
            return Positioned.fill(
              key: ValueKey('hib_${tab.id}'),
              child: Visibility(
                visible: isShowing,
                maintainState: false,
                child: HibernatedTabPlaceholder(tab: tab, snapshot: cachedSnapshot),
              ),
            );
          }

          final engine = ref.watch(browserEngineProvider(tab.id));
          final snapshotBytes = (isShowing && webViewSnapshot?.tabId == tab.id) ? webViewSnapshot!.bytes : null;

          return Positioned.fill(
            key: ValueKey('vis_${tab.id}'),
            child: Visibility(
              visible: isShowing,
              maintainState: true,
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    engine.buildWidget(tabId: tab.id, initialUrl: tab.url),
                    if (snapshotBytes != null)
                      Positioned.fill(
                        child: Image.memory(
                          snapshotBytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          // Bound the decode like every other snapshot site
                          // (O-47): an unbounded full-screen capture sits in
                          // the image cache at full ARGB size. Logical width
                          // trades sharpness for ~1/9 the memory; the image is
                          // only visible during the sheet's fade.
                          cacheWidth: MediaQuery.of(context).size.width.round(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        const WebViewSkeletonOverlay(),
        if (activeTabWebError != null && activeUrl.isNotEmpty)
          Positioned.fill(
            child: CustomErrorScreen(
              error: activeTabWebError,
              url: activeUrl,
              onRetry: () {
                final tabId = isGhost ? ghostOrder[ghostActiveIndex] : normalOrder[normalActiveIndex];
                if (isGhost) {
                  ref.read(ghostTabsProvider.notifier).setWebError(tabId, null);
                } else {
                  ref.read(tabsProvider.notifier).setWebError(tabId, null);
                }
                ref.read(activeBrowserEngineProvider)?.reload();
              },
            ),
          ),
      ],
    );
  }
}
