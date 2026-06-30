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

Widget buildMobileBottomBar({
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
  final mediaPadBottom = MediaQuery.of(context).padding.bottom;
  final barColor = isGhost ? const Color(0xFF0D0D0D) : appBarColor;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Fixed 3px slot — prevents layout jump when progress bar appears/disappears
      SizedBox(
        height: 3,
        child: BrowserProgressBar(color: primaryAccent),
      ),
      Container(
        color: barColor,
        padding: EdgeInsets.only(bottom: mediaPadBottom),
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
                // Snapshot-swap: capture the live page and hand it to
                // BrowserView (which Offstages the webview) so the sheet
                // animates without the Hybrid-Composition compositing tax.
                // A null capture falls back to the live webview — no regression.
                final engine = ref.read(activeBrowserEngineProvider);
                final shot = await engine?.takeSnapshot();
                if (!context.mounted) return;
                if (shot != null) {
                  ref.read(webViewSnapshotProvider.notifier).state =
                      WebViewSnapshot(tabId: activeTab.id, bytes: shot);
                }
                // The snapshot stops the page *compositing*; hibernate() (native
                // pause) also stops it *producing* frames, so a video page
                // doesn't burn CPU/battery behind the sheet.
                unawaited(engine?.hibernate());
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const FractionallySizedBox(
                      heightFactor: 0.8, child: TabsSheet()),
                );
                unawaited(engine?.wake());
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
    ],
  );
}
