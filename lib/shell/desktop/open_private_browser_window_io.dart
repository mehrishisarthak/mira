import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/core/notifiers/ghost_notifier.dart';

/// Opens a new Ghost tab and switches the workspace into Ghost mode.
///
/// Despite the name this does NOT open an OS window — Qyx is single-window and
/// Ghost mode is a workspace within it. The name is retained only because it is
/// the desktop menu/hotkey entry point.
void openMiraPrivateBrowserWindow(WidgetRef ref) {
  // Add the tab BEFORE flipping the mode, matching the mobile drawer and the
  // sidebar toggle. Switching first leaves the shell in Ghost mode with an
  // empty ghost tab list for a beat, which the ghost side-effect listener
  // treats as "no ghost tabs left".
  //
  // Unconditional, also matching mobile. The old `if (tabs.isEmpty)` guard
  // meant that once any ghost tab existed the action silently did nothing —
  // which is why "New private window" appeared dead on desktop.
  ref.read(ghostTabsProvider.notifier).addTab();
  ref.read(isGhostModeProvider.notifier).state = true;
}
