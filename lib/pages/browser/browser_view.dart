import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isGhost = ref.read(isGhostModeProvider);
      final initialState =
          isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
      if (initialState.tabs.isNotEmpty) {
        final activeId = initialState.tabs[initialState.activeIndex].id;
        ref.read(hibernationProvider.notifier).wakeTab(activeId);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Note: Lifecycle management (pause/resume) can be handled via the BrowserEngine instances
    // managed by the browserEngineProvider family.
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);
    
    // Side effects logic updated to use new providers
    registerBrowserViewSideEffects(
      ref: ref,
      isMounted: () => mounted,
    );

    final tabsState = ref.watch(isGhost ? ghostTabsProvider : tabsProvider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;

    final awakeTabIds = ref.watch(hibernationProvider);

    final errorMessage =
        ref.watch(browserChromeProvider.select((s) => s.webError));

    if (errorMessage != null && tabs.isNotEmpty) {
      // CustomErrorScreen should be updated similarly if it has native imports
      // For now, assuming it's manageable.
    }

    return Stack(
      children: [
        ...tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isShowing = index == activeIndex;

          if (!awakeTabIds.contains(tab.id)) {
            return Positioned.fill(
              key: ValueKey('hib_${tab.id}'),
              child: Visibility(
                visible: isShowing,
                child: Center(child: Text("Tab Hibernating: ${tab.url}")),
              ),
            );
          }

          final engine = ref.watch(browserEngineProvider(tab.id));

          return Positioned.fill(
            key: ValueKey('vis_${tab.id}'),
            child: Visibility(
              visible: isShowing,
              maintainState: true,
              child: engine.buildWidget(tabId: tab.id),
            ),
          );
        }),
        const WebViewSkeletonOverlay(),
      ],
    );
  }
}
