import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mira/core/entities/tab_entity.dart';
import 'package:mira/core/notifiers/bookmarks_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';
import 'package:mira/pages/mira_drawer.dart';
import 'package:mira/pages/main_screen/browser_progress_bar.dart';
import 'package:mira/pages/main_screen/main_screen_security.dart';

Future<void> showDesktopMiraMenuPopup(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 56, right: 12),
          child: Material(
            elevation: 18,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 380,
              height: (size.height - 96).clamp(420.0, 780.0),
              child: const MiraMenuPage(desktopOverlay: true),
            ),
          ),
        ),
      );
    },
  );
}

Widget buildDesktopToolbar({
  required BuildContext context,
  required WidgetRef ref,
  required Color bgColor,
  required Color contentColor,
  required Color accentColor,
  required Color hintColor,
  required BrowserTab activeTab,
  required bool isGhost,
  required IconData securityIcon,
  required Color securityColor,
  required bool isBookmarked,
  required bool hasWebView,
  required TextEditingController urlController,
  required FocusNode urlFocusNode,
  required void Function(String) onUrlSubmitted,
  required VoidCallback onFindPressed,
}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    color: bgColor,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: contentColor, size: 20),
                tooltip: 'Back',
                onPressed: hasWebView
                    ? () => ref.read(browserChromeProvider).engine?.goBack()
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward, color: contentColor, size: 20),
                tooltip: 'Forward',
                onPressed: hasWebView
                    ? () => ref.read(browserChromeProvider).engine?.goForward()
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DesktopAddressBar(
                  urlController: urlController,
                  urlFocusNode: urlFocusNode,
                  activeTab: activeTab,
                  isGhost: isGhost,
                  isBookmarked: isBookmarked,
                  contentColor: contentColor,
                  accentColor: accentColor,
                  hintColor: hintColor,
                  securityIcon: securityIcon,
                  securityColor: securityColor,
                  onUrlSubmitted: onUrlSubmitted,
                  context: context,
                  ref: ref,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.search, color: contentColor.withValues(alpha: 0.6), size: 20),
                tooltip: 'Find in page',
                onPressed: onFindPressed,
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: contentColor, size: 20),
                onPressed: () => showDesktopMiraMenuPopup(context),
              ),
            ],
          ),
        ),
        BrowserProgressBar(color: accentColor, minHeight: 2),
      ],
    ),
  );
}

// ── Desktop address bar with domain-only unfocused display ────────────────────

class _DesktopAddressBar extends StatefulWidget {
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final BrowserTab activeTab;
  final bool isGhost;
  final bool isBookmarked;
  final Color contentColor;
  final Color accentColor;
  final Color hintColor;
  final IconData securityIcon;
  final Color securityColor;
  final void Function(String) onUrlSubmitted;
  final BuildContext context;
  final WidgetRef ref;

  const _DesktopAddressBar({
    required this.urlController,
    required this.urlFocusNode,
    required this.activeTab,
    required this.isGhost,
    required this.isBookmarked,
    required this.contentColor,
    required this.accentColor,
    required this.hintColor,
    required this.securityIcon,
    required this.securityColor,
    required this.onUrlSubmitted,
    required this.context,
    required this.ref,
  });

  @override
  State<_DesktopAddressBar> createState() => _DesktopAddressBarState();
}

class _DesktopAddressBarState extends State<_DesktopAddressBar> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    widget.urlFocusNode.addListener(_onFocusChange);
    widget.urlController.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.urlFocusNode.removeListener(_onFocusChange);
    widget.urlController.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _hasFocus = widget.urlFocusNode.hasFocus);
  }

  void _onControllerChange() {
    // Rebuild domain text when URL changes while unfocused.
    if (mounted && !_hasFocus) setState(() {});
  }

  String get _domain {
    final url = widget.urlController.text;
    if (url.isEmpty) return '';
    try {
      final host = Uri.parse(url).host;
      return host.replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGhost = widget.isGhost;
    final showDomain = !_hasFocus && widget.urlController.text.isNotEmpty;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isGhost
            ? Colors.redAccent.withValues(alpha: 0.08)
            : widget.contentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: isGhost
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          Tooltip(
            message: widget.activeTab.url.isEmpty
                ? 'Site info'
                : 'Connection & site info',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: widget.activeTab.url.isEmpty
                  ? null
                  : () => showSecurityDialogForUrl(
                        widget.context,
                        widget.activeTab.url,
                        widget.securityColor,
                        widget.contentColor,
                      ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(widget.securityIcon,
                    color: widget.securityColor, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: showDomain
                ? GestureDetector(
                    onTap: () {
                      widget.urlFocusNode.requestFocus();
                      widget.urlController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: widget.urlController.text.length,
                      );
                    },
                    child: Text(
                      _domain,
                      style: GoogleFonts.jetBrainsMono(
                        color: widget.contentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : TextField(
                    controller: widget.urlController,
                    focusNode: widget.urlFocusNode,
                    style: GoogleFonts.jetBrainsMono(
                        color: widget.contentColor, fontSize: 13),
                    cursorColor: widget.accentColor,
                    decoration: InputDecoration(
                      hintText: isGhost
                          ? 'Private browsing'
                          : 'Search or enter address',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: GoogleFonts.jetBrainsMono(
                          color: isGhost
                              ? Colors.redAccent.withValues(alpha: 0.5)
                              : widget.hintColor,
                          fontSize: 13),
                    ),
                    onTap: () {
                      widget.urlController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: widget.urlController.text.length,
                      );
                    },
                    onSubmitted: widget.onUrlSubmitted,
                  ),
          ),
          if (widget.activeTab.url.isNotEmpty && !isGhost)
            IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                widget.isBookmarked ? Icons.star : Icons.star_border,
                color: widget.isBookmarked
                    ? Colors.yellowAccent
                    : widget.hintColor,
                size: 18,
              ),
              onPressed: () => widget.ref
                  .read(bookmarksProvider.notifier)
                  .toggleBookmark(
                      widget.activeTab.url, widget.activeTab.title),
            ),
        ],
      ),
    );
  }
}
