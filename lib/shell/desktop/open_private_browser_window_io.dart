import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';

/// Transitions the single-window UI into the Private (Ghost) Workspace.
void openMiraPrivateBrowserWindow(WidgetRef ref) {
  // 1. Switch the UI to Ghost Mode
  ref.read(isGhostModeProvider.notifier).state = true;
  
  // 2. If the ghost workspace is empty, spin up a new private tab
  if (ref.read(ghostTabsProvider).tabs.isEmpty) {
    ref.read(ghostTabsProvider.notifier).addTab();
  }
}