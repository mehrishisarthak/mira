import 'dart:io';

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/security_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';
import 'package:mira/shell/browser/browser_provider.dart';
import 'package:mira/pages/custom_error_screen.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

import 'browser_side_effects.dart';
import 'in_app_browser_tab_content.dart';
import 'webview_skeleton_overlay.dart';
import 'webview_session.dart';

class BrowserView extends ConsumerStatefulWidget {
  const BrowserView({super.key});

  @override
  ConsumerState<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends ConsumerState<BrowserView>
    with WidgetsBindingObserver {
  final WebViewSession _session = WebViewSession();

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

      final security = ref.read(securityProvider);
      ref.read(browserServiceProvider).applyProxy(security);
    });
  }

  @override
  void dispose() {
    _session.cancelSkeletonDismissTimer();
    _session.disposeFindControllers();
    WidgetsBinding.instance.removeObserver(this);
    _session.controllers.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final shouldPauseAll = state == AppLifecycleState.paused ||
        (!isDesktop && state == AppLifecycleState.inactive);
    if (shouldPauseAll) {
      for (var controller in _session.controllers.values) {
        try {
          controller.pause();
        } catch (e) {
          debugPrint("Safe Pause Fail: $e");
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      final isGhost = ref.read(isGhostModeProvider);
      final tabsState =
          isGhost ? ref.read(ghostTabsProvider) : ref.read(tabsProvider);
      if (tabsState.tabs.isNotEmpty) {
        final activeTabId = tabsState.tabs[tabsState.activeIndex].id;
        _session.updateControllersPauseState(activeTabId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = ref.watch(isGhostModeProvider);
    registerBrowserViewSideEffects(
      ref: ref,
      session: _session,
      isMounted: () => mounted,
    );

    ref.watch(
      (isGhost ? ghostTabsProvider : tabsProvider).select((s) =>
          '${s.activeIndex}|${s.tabs.map((t) => '${t.id}:${t.url.isEmpty ? 0 : 1}').join(',')}'),
    );

    final tabsState = ref.read(isGhost ? ghostTabsProvider : tabsProvider);
    final tabs = tabsState.tabs;
    final activeIndex = tabsState.activeIndex;
    final activeTabId = tabs.isNotEmpty ? tabs[activeIndex].id : '';

    final awakeTabIds = ref.watch(hibernationProvider);

    final securityState = ref.read(securityProvider);
    final theme = ref.read(themeProvider);

    final errorMessage =
        ref.watch(browserChromeProvider.select((s) => s.webError));

    if (errorMessage != null && tabs.isNotEmpty) {
      return CustomErrorScreen(
        error: errorMessage,
        url: tabs[activeIndex].url,
        onRetry: () {
          HapticFeedback.mediumImpact();
          ref.read(browserChromeProvider.notifier).clearWebError();
          final retryController = ref.read(browserChromeProvider).controller;
          if (retryController != null) {
            retryController.reload();
            return;
          }
          final active = ref.read(currentActiveTabProvider);
          if (active.url.isEmpty) return;
          ref.read(hibernationProvider.notifier).wakeTab(active.id);
        },
      );
    }

    final forceDarkSetting = (theme.mode == ThemeMode.light)
        ? ForceDark.OFF
        : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO);

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (e) => _session.lastPointerPosition = e.position,
      onPointerSignal: (signal) {
        if (signal is! PointerScrollEvent) return;
        final isDesktop = !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
        if (!isDesktop) return;
        final dx = signal.scrollDelta.dx;
        final dy = signal.scrollDelta.dy;
        if (dx.abs() <= dy.abs() * 2 || dx.abs() < 40) return;
        final now = DateTime.now();
        if (_session.lastHorizontalWheelNavAt != null &&
            now.difference(_session.lastHorizontalWheelNavAt!) <
                const Duration(milliseconds: 550)) {
          return;
        }
        _session.lastHorizontalWheelNavAt = now;
        final controller = ref.read(browserChromeProvider).controller;
        if (controller == null) return;
        if (dx > 0) {
          controller.goForward();
        } else {
          controller.goBack();
        }
      },
      child: Stack(
        children: [
          ...tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isShowing = index == activeIndex;

            final content = buildBrowserTabContent(
              context: context,
              ref: ref,
              session: _session,
              tab: tab,
              activeTabId: activeTabId,
              isGhost: isGhost,
              awakeTabIds: awakeTabIds,
              securityState: securityState,
              theme: theme,
              forceDarkSetting: forceDarkSetting,
              isMounted: () => mounted,
            );

            return Positioned.fill(
              key: ValueKey('vis_${tab.id}'),
              child: IgnorePointer(
                ignoring: !isShowing,
                child: Opacity(
                  opacity: isShowing ? 1.0 : 0.0,
                  child: content,
                ),
              ),
            );
          }),
          const WebViewSkeletonOverlay(),
        ],
      ),
    );
  }
}
