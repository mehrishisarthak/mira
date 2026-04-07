import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/desktop/private_standalone_window_provider.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/shell/browser/browser_provider.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

import 'webview_platform.dart';
import 'webview_session.dart';

/// Side effects only — **must** be called from [build]: Riverpod only allows
/// [ref.listen] during a [ConsumerWidget] build.
void registerBrowserViewSideEffects({
  required WidgetRef ref,
  required WebViewSession session,
  required bool Function() isMounted,
}) {
  ref.listen(tabsProvider, (previous, next) {
    if (!ref.read(isGhostModeProvider)) {
      final prevId = activeTabIdFromState(previous);
      final nextId = activeTabIdFromState(next);
      if (prevId != nextId) {
        ref.read(browserChromeProvider.notifier).clearWebError();
        session.cancelSkeletonDismissTimer();
      }
      session.cleanUpClosedTabs(next.tabs, ref);
      if (next.tabs.isNotEmpty) {
        final newActiveId = next.tabs[next.activeIndex].id;
        final prevActiveId = activeTabIdFromState(previous);
        if (previous == null ||
            previous.activeIndex != next.activeIndex ||
            prevActiveId != newActiveId) {
          ref.read(hibernationProvider.notifier).wakeTab(newActiveId);
          session.updateControllersPauseState(newActiveId);
        }
      }
    }
  });

  ref.listen(ghostTabsProvider, (previous, next) {
    session.cleanUpClosedTabs(next.tabs, ref);

    if (next.tabs.isEmpty) {
      if (ref.read(privateStandaloneWindowProvider)) {
        ref.read(ghostTabsProvider.notifier).addTab();
        return;
      }
      if (ref.read(isGhostModeProvider)) {
        ref.read(isGhostModeProvider.notifier).state = false;
      }
      return;
    }

    if (ref.read(isGhostModeProvider)) {
      final prevId = activeTabIdFromState(previous);
      final nextId = activeTabIdFromState(next);
      if (prevId != nextId) {
        ref.read(browserChromeProvider.notifier).clearWebError();
        session.cancelSkeletonDismissTimer();
      }
      final newActiveId = next.tabs[next.activeIndex].id;
      final prevActiveId = activeTabIdFromState(previous);
      if (previous == null ||
          previous.activeIndex != next.activeIndex ||
          prevActiveId != newActiveId) {
        ref.read(hibernationProvider.notifier).wakeTab(newActiveId);
        session.updateControllersPauseState(newActiveId);
      }
    }
  });

  ref.listen(isGhostModeProvider, (_, isGhostNow) {
    ref.read(browserChromeProvider.notifier).clearWebError();
    session.cancelSkeletonDismissTimer();
    final switchedState =
        isGhostNow ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
    if (switchedState.tabs.isNotEmpty) {
      final activeId = switchedState.tabs[switchedState.activeIndex].id;
      ref.read(hibernationProvider.notifier).wakeTab(activeId);
    }
  });

  ref.listen(securityProvider, (previous, next) {
    if (previous?.isProxyEnabled != next.isProxyEnabled ||
        previous?.proxyUrl != next.proxyUrl ||
        previous?.proxyAllowInsecureCertificates !=
            next.proxyAllowInsecureCertificates) {
      ref.read(browserServiceProvider).applyProxy(next);
    }
  });

  ref.listen(themeProvider, (_, next) => session.applyThemeToAllControllers(next, ref));

  ref.listen(hibernationProvider, (previous, next) {
    final prev = previous ?? <String>{};
    session.onHibernationEvicted(prev, next);
  });

  ref.listen(currentActiveTabProvider, (previous, next) {
    ref.read(activeFindInteractionProvider.notifier).state =
        browserWebViewSupportsNativeFindInteraction()
            ? session.findControllers[next.id]
            : null;
    if (previous?.id != next.id) {
      session.syncChromeToActiveWebView(next, ref);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isMounted()) return;
        session.webviewJustCreatedForTabId = null;
        final now = ref.read(currentActiveTabProvider);
        if (now.id != next.id) return;
        session.syncChromeToActiveWebView(now, ref, updateProgress: false);
      });
    }
  });
}
