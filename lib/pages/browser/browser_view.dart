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

class _BrowserViewState extends ConsumerState<BrowserView>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run the one-time initial sync after the first frame so providers are ready.
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
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);

    registerBrowserViewSideEffects(ref: ref);

    // Watch both providers for structural changes to either stack
    ref.watch(tabsProvider.select((s) =>
        '${s.activeIndex}|${s.tabs.map((t) => '${t.id}:${t.url.isEmpty}').join(',')}'));
    ref.watch(ghostTabsProvider.select((s) =>
        '${s.activeIndex}|${s.tabs.map((t) => '${t.id}:${t.url.isEmpty}').join(',')}'));

    final normalState = ref.read(tabsProvider);
    final ghostState = ref.read(ghostTabsProvider);
    
    final normalTabs = normalState.tabs;
    final normalActiveIndex = normalState.activeIndex;
    
    final ghostTabs = ghostState.tabs;
    final ghostActiveIndex = ghostState.activeIndex;

    final awakeTabIds = ref.watch(hibernationProvider);
    final webViewSnapshot = ref.watch(webViewSnapshotProvider);
    
    // The active tab whose custom error or URL we care about at the top level
    final activeUrl = isGhost 
      ? (ghostTabs.isNotEmpty ? ghostTabs[ghostActiveIndex].url : '') 
      : (normalTabs.isNotEmpty ? normalTabs[normalActiveIndex].url : '');
      
    final activeTabWebError = isGhost
      ? (ghostTabs.isNotEmpty ? ghostTabs[ghostActiveIndex].webError : null)
      : (normalTabs.isNotEmpty ? normalTabs[normalActiveIndex].webError : null);

    return Stack(
      children: [
        // Map over both lists simultaneously
        ...[
          ...normalTabs.asMap().entries.map((e) => MapEntry(e.key, {'tab': e.value, 'isGhost': false})),
          ...ghostTabs.asMap().entries.map((e) => MapEntry(e.key, {'tab': e.value, 'isGhost': true}))
        ].map((entry) {
          final index = entry.key;
          final tabData = entry.value;
          final tab = tabData['tab'] as BrowserTab;
          final isTabGhost = tabData['isGhost'] as bool;
          
          final isActiveMode = isTabGhost == isGhost;
          final isShowing = isActiveMode && index == (isTabGhost ? ghostActiveIndex : normalActiveIndex);

          // Inactive mode tabs get visibility: false, maintainState: true
          
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
            final cachedSnapshot = ref.watch(tabSnapshotCacheProvider)[tab.id];
            return Positioned.fill(
              key: ValueKey('hib_${tab.id}'),
              child: Visibility(
                visible: isShowing,
                maintainState: true,
                child: HibernatedTabPlaceholder(tab: tab, snapshot: cachedSnapshot),
              ),
            );
          }

          final engine = ref.watch(browserEngineProvider(tab.id));
          
          final snapshotBytes =
              (isShowing && webViewSnapshot?.tabId == tab.id)
                  ? webViewSnapshot!.bytes
                  : null;

          return Positioned.fill(
            key: ValueKey('vis_${tab.id}'),
            child: Visibility(
              visible: isShowing,
              maintainState: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Offstage(
                    offstage: snapshotBytes != null || tab.webError != null,
                    child:
                        engine.buildWidget(tabId: tab.id, initialUrl: tab.url),
                  ),
                  if (snapshotBytes != null)
                    Image.memory(
                      snapshotBytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                ],
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
                final tabId = isGhost ? ghostTabs[ghostActiveIndex].id : normalTabs[normalActiveIndex].id;
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
