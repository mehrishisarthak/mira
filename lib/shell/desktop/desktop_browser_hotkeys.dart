import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

/// Returns `true` when the event was handled (Chrome-like desktop shortcuts).
bool handleDesktopBrowserHotkey({
  required KeyEvent event,
  required bool mounted,
  required WidgetRef ref,
  required FocusNode urlFocusNode,
  required TextEditingController urlController,
  required void Function() openFindDialog,
}) {
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) return false;
  if (!mounted) return false;
  if (event is! KeyDownEvent) return false;

  final isMac = Platform.isMacOS;
  final mod = isMac
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  final key = event.logicalKey;

  if (!mod) {
    if (key == LogicalKeyboardKey.f5) {
      ref.read(browserChromeProvider).controller?.reload();
      return true;
    }
    if (key == LogicalKeyboardKey.f6) {
      urlFocusNode.requestFocus();
      urlController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: urlController.text.length,
      );
      return true;
    }
    return false;
  }

  final web = ref.read(browserChromeProvider).controller;

  if (key == LogicalKeyboardKey.keyT) {
    ref.read(tabsProvider.notifier).addTab();
    ref.read(isGhostModeProvider.notifier).state = false;
    return true;
  }

  if (key == LogicalKeyboardKey.keyW) {
    final isGhost = ref.read(isGhostModeProvider);
    final active = ref.read(currentActiveTabProvider);
    if (isGhost) {
      ref.read(ghostTabsProvider.notifier).closeTab(active.id);
    } else {
      ref.read(tabsProvider.notifier).closeTab(active.id);
    }
    return true;
  }

  if (key == LogicalKeyboardKey.keyR) {
    web?.reload();
    return true;
  }

  if (key == LogicalKeyboardKey.keyL) {
    urlFocusNode.requestFocus();
    urlController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: urlController.text.length,
    );
    return true;
  }

  if (key == LogicalKeyboardKey.keyF) {
    openFindDialog();
    return true;
  }

  if (key == LogicalKeyboardKey.equal ||
      key == LogicalKeyboardKey.numpadAdd) {
    web?.zoomIn();
    return true;
  }

  if (key == LogicalKeyboardKey.minus ||
      key == LogicalKeyboardKey.numpadSubtract) {
    web?.zoomOut();
    return true;
  }

  if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
    web?.zoomBy(zoomFactor: 1.0);
    return true;
  }

  if (key == LogicalKeyboardKey.tab) {
    final back = HardwareKeyboard.instance.isShiftPressed;
    _cycleActiveTab(ref, forward: !back);
    return true;
  }

  if (HardwareKeyboard.instance.isAltPressed) {
    if (key == LogicalKeyboardKey.arrowLeft) {
      web?.goBack();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      web?.goForward();
      return true;
    }
  }

  return false;
}

void _cycleActiveTab(WidgetRef ref, {required bool forward}) {
  final isGhost = ref.read(isGhostModeProvider);
  if (isGhost) {
    final s = ref.read(ghostTabsProvider);
    if (s.tabs.isEmpty) return;
    final n = s.tabs.length;
    final next = forward
        ? (s.activeIndex + 1) % n
        : (s.activeIndex - 1 + n) % n;
    ref.read(ghostTabsProvider.notifier).switchTab(next);
  } else {
    final s = ref.read(tabsProvider);
    if (s.tabs.isEmpty) return;
    final n = s.tabs.length;
    final next = forward
        ? (s.activeIndex + 1) % n
        : (s.activeIndex - 1 + n) % n;
    ref.read(tabsProvider.notifier).switchTab(next);
  }
}
