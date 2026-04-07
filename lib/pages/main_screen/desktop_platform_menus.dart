import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

List<PlatformMenu> buildDesktopMainPlatformMenus({
  required WidgetRef ref,
  required VoidCallback openDesktopFindBar,
  required FocusNode urlFocusNode,
  required TextEditingController urlController,
}) {
  return [
    PlatformMenu(
      label: 'File',
      menus: [
        PlatformMenuItem(
          label: 'New Tab',
          onSelected: () {
            ref.read(tabsProvider.notifier).addTab();
            ref.read(isGhostModeProvider.notifier).state = false;
          },
        ),
        PlatformMenuItem(
          label: 'Close Tab',
          onSelected: () {
            final ghost = ref.read(isGhostModeProvider);
            final active = ref.read(currentActiveTabProvider);
            if (ghost) {
              ref.read(ghostTabsProvider.notifier).closeTab(active.id);
            } else {
              ref.read(tabsProvider.notifier).closeTab(active.id);
            }
          },
        ),
        PlatformMenuItem(
          label: 'Exit',
          onSelected: () => SystemNavigator.pop(),
        ),
      ],
    ),
    PlatformMenu(
      label: 'Edit',
      menus: [
        PlatformMenuItem(
          label: 'Find in Page…',
          onSelected: openDesktopFindBar,
        ),
        PlatformMenuItem(
          label: 'Focus Address Bar',
          onSelected: () {
            urlFocusNode.requestFocus();
            urlController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: urlController.text.length,
            );
          },
        ),
      ],
    ),
    PlatformMenu(
      label: 'View',
      menus: [
        PlatformMenuItem(
          label: 'Reload',
          onSelected: () =>
              ref.read(browserChromeProvider).controller?.reload(),
        ),
      ],
    ),
  ];
}
