import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
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

    final provider = isGhost ? ghostTabsProvider : tabsProvider;
    // Rebuild only on structural change — add/remove/switch and the
    // branding<->webview flip (a tab's url emptying/filling). A url/title tick
    // during load must NOT rebuild this Stack: each webview is keyed by tabId
    // and reads initialUrl once at creation (O-06).
    ref.watch(provider.select((s) =>
        '${s.activeIndex}|${s.tabs.map((t) => '${t.id}:${t.url.isEmpty}').join(',')}'));
    final tabsState = ref.read(provider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;

    final awakeTabIds = ref.watch(hibernationProvider);
    final webError = ref.watch(browserChromeProvider.select((s) => s.webError));
    final webViewSnapshot = ref.watch(webViewSnapshotProvider);
    final activeUrl = tabs.isNotEmpty ? tabs[activeIndex].url : '';

    return Stack(
      children: [
        ...tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isShowing = index == activeIndex;

          if (tab.url.isEmpty) {
             return Positioned.fill(
              key: ValueKey('brand_${tab.id}'),
              child: Visibility(
                visible: isShowing,
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
                child: HibernatedTabPlaceholder(tab: tab, snapshot: cachedSnapshot),
              ),
            );
          }

          final engine = ref.watch(browserEngineProvider(tab.id));
          // While an overlay (tab sheet) is open, swap the active page for its
          // screenshot and Offstage the live webview: this drops the HC surface
          // out of the composite so the overlay animates without the
          // platform-view tax, while keeping the native view alive (no reload
          // on restore). Same offstage-but-alive pattern as inactive tabs.
          // Scoped to the captured tab so switching tabs from the sheet shows
          // the new tab live, not the previous tab's screenshot.
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
                    offstage: snapshotBytes != null,
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
        if (webError != null && activeUrl.isNotEmpty)
          Positioned.fill(
            child: CustomErrorScreen(
              error: webError,
              url: activeUrl,
              onRetry: () {
                ref.read(browserChromeProvider.notifier).clearWebError();
                ref.read(activeBrowserEngineProvider)?.reload();
              },
            ),
          ),
      ],
    );
  }
}
