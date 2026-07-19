import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/constants/app_fonts.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/bookmarks_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/mira_drawer.dart';
import 'package:mira/pages/main_screen/browser_progress_bar.dart';
import 'package:mira/pages/main_screen/main_screen_haptics.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';
import 'package:mira/pages/tab_screen.dart';
import 'package:mira/core/services/snapshot_service.dart';

Widget buildMobileTopBar({
  required BuildContext context,
  required WidgetRef ref,
  required TextEditingController urlController,
  required FocusNode urlFocusNode,
  required Color appBarColor,
  required IconData securityIcon,
  required Color securityColor,
  required String activeUrl,
  required Color contentColor,
  required Color primaryAccent,
  required bool isGhost,
  required Color hintColor,
  required bool isBookmarked,
  required BrowserTab activeTab,
  required int tabCount,
  required void Function(MainScreenHapticKind) triggerHaptic,
  required void Function(String) onUrlSubmitted,
  required VoidCallback onBackPressed,
  required VoidCallback onGhostToggle,
}) {
  // Top-pinned bar: accommodate the top safe-area notch/status bar instead of
  // the bottom chin, since this bar now lives at the very top of the Column
  // (see mainscreen.dart's mobile layout pivot).
  final mediaPadTop = MediaQuery.of(context).padding.top;
  final barColor = isGhost ? const Color(0xFF0D0D0D) : appBarColor;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        color: barColor,
        padding: EdgeInsets.only(top: mediaPadTop),
        child: Row(
          children: [
            // ── Back button ──────────────────────────────────────────────────
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: contentColor.withValues(alpha: 0.7),
                size: 20,
              ),
              onPressed: onBackPressed,
              tooltip: 'Back',
            ),

            // ── Ghost toggle ─────────────────────────────────────────────────
            GestureDetector(
              onTap: onGhostToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.visibility_outlined,
                  size: 20,
                  color: isGhost
                      ? Colors.redAccent
                      : contentColor.withValues(alpha: 0.3),
                ),
              ),
            ),

            // ── URL pill ─────────────────────────────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: contentColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => showSecurityDialogForUrl(
                        context,
                        activeUrl,
                        securityColor,
                        contentColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(securityIcon, color: securityColor, size: 14),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: urlController,
                        focusNode: urlFocusNode,
                        style: jetBrainsMono(
                          color: contentColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        cursorColor: primaryAccent,
                        decoration: InputDecoration(
                          hintText: isGhost
                              ? 'Ghost Mode Active'
                              : 'Search or enter address',
                          border: InputBorder.none,
                          hintStyle: jetBrainsMono(
                              color: hintColor, fontSize: 13),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        textInputAction: TextInputAction.go,
                        onTap: () => urlController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: urlController.text.length),
                        onSubmitted: onUrlSubmitted,
                      ),
                    ),
                    if (activeUrl.isNotEmpty && !isGhost)
                      IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.star : Icons.star_border,
                          color: isBookmarked ? Colors.yellowAccent : hintColor,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          triggerHaptic(MainScreenHapticKind.selection);
                          ref
                              .read(bookmarksProvider.notifier)
                              .toggleBookmark(activeUrl, activeTab.title);
                        },
                      ),
                  ],
                ),
              ),
            ),

            // ── Tab count ────────────────────────────────────────────────────
            InkWell(
              onTap: () async {
                triggerHaptic(MainScreenHapticKind.selection);
                final engine = ref.read(activeBrowserEngineProvider);
                final capturedTabId = activeTab.id;

                // Guards the unawaited capture below against writing state
                // after this transition has already resolved and cleaned up.
                // Without this: if takeSnapshot() is still in flight when the
                // switcher closes (e.g. the user tapped a different tab and
                // popped back quickly), the capture can resolve *after* the
                // "resume + clear overlay" cleanup below already ran — and
                // silently re-stamp webViewSnapshotProvider with a frozen
                // image of this tab, and (out of order) pause an engine that
                // was just resumed. Nothing else ever clears that stale
                // state, so the next time the user switches back to this
                // tab, the frozen snapshot reappears over its already-live,
                // already-resumed engine and just sits there.
                var transitionActive = true;

                // 1. Snapshot-swap: capture the live page in parallel
                unawaited(() async {
                  final shot = await engine?.takeSnapshot();
                  if (!context.mounted || !transitionActive) return;
                  if (shot != null) {
                    ref.read(webViewSnapshotProvider.notifier).state =
                        WebViewSnapshot(tabId: capturedTabId, bytes: shot);
                    // Also cache it instantly in memory for the transition
                    ref.read(tabSnapshotCacheProvider.notifier).update((state) => {
                      ...state,
                      capturedTabId: TabSnapshotData(bytes: shot),
                    });

                    // Background disk write for normal tabs
                    if (!isGhost) {
                      unawaited(ref.read(snapshotServiceProvider).writeSnapshot(capturedTabId, shot));
                    }
                  }
                  // The snapshot stops the page *compositing*; pauseRendering() (native
                  // pause) also stops it *producing* frames.
                  unawaited(engine?.pauseRendering());
                }());

                // 2. Custom transition controller
                await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const TabsSheet(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                          ),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 250),
                    reverseTransitionDuration: const Duration(milliseconds: 200),
                  ),
                );

                transitionActive = false;
                unawaited(engine?.resumeRendering());
                if (!context.mounted) return;
                ref.read(webViewSnapshotProvider.notifier).state = null;
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$tabCount',
                  style: jetBrainsMono(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // ── Menu button ──────────────────────────────────────────────────
            IconButton(
              icon: Icon(Icons.more_vert, color: contentColor),
              onPressed: () {
                triggerHaptic(MainScreenHapticKind.selection);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MiraMenuPage()),
                );
              },
            ),
          ],
        ),
      ),
      // Fixed 3px slot — prevents layout jump when progress bar appears/disappears
      SizedBox(
        height: 3,
        child: BrowserProgressBar(color: primaryAccent),
      ),
    ],
  );
}


