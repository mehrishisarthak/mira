import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/bookmarks_notifier.dart';
import 'package:mira/pages/mira_drawer.dart';
import 'package:mira/pages/main_screen/main_screen_haptics.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';
import 'package:mira/pages/tab_screen.dart';

PreferredSizeWidget buildMobileMainAppBar({
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
  required double progress,
  required void Function(MainScreenHapticKind) triggerHaptic,
  required void Function(String) onUrlSubmitted,
}) {
  return AppBar(
    backgroundColor: appBarColor,
    titleSpacing: 0,
    leading: IconButton(
      icon: Icon(securityIcon, color: securityColor),
      onPressed: () => showSecurityDialogForUrl(
        context,
        ref,
        activeUrl,
        securityColor,
        contentColor,
      ),
    ),
    title: TextField(
      controller: urlController,
      focusNode: urlFocusNode,
      style: GoogleFonts.jetBrainsMono(
          color: contentColor, fontWeight: FontWeight.w500, fontSize: 14),
      cursorColor: primaryAccent,
      decoration: InputDecoration(
        hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
        border: InputBorder.none,
        hintStyle: GoogleFonts.jetBrainsMono(color: hintColor),
        suffixIcon: activeUrl.isNotEmpty && !isGhost
            ? IconButton(
                icon: Icon(isBookmarked ? Icons.star : Icons.star_border,
                    color: isBookmarked ? Colors.yellowAccent : hintColor,
                    size: 20),
                onPressed: () {
                  triggerHaptic(MainScreenHapticKind.selection);
                  ref
                      .read(bookmarksProvider.notifier)
                      .toggleBookmark(activeUrl, activeTab.title);
                },
              )
            : null,
      ),
      textInputAction: TextInputAction.go,
      onTap: () => urlController.selection =
          TextSelection(baseOffset: 0, extentOffset: urlController.text.length),
      onSubmitted: onUrlSubmitted,
    ),
    actions: [
      InkWell(
        onTap: () {
          triggerHaptic(MainScreenHapticKind.selection);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const FractionallySizedBox(
                heightFactor: 0.8, child: TabsSheet()),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: primaryAccent, borderRadius: BorderRadius.circular(8)),
          child: Text("$tabCount",
              style: GoogleFonts.jetBrainsMono(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
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
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(2),
      child: progress < 1.0 && activeUrl.isNotEmpty
          ? LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              color: primaryAccent)
          : Container(height: 2, color: Colors.transparent),
    ),
  );
}
