import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/constants/app_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'package:qyx/core/entities/tab_entity.dart';
import 'package:qyx/core/notifiers/bookmarks_notifier.dart';
import 'package:qyx/pages/browser_chrome_providers.dart';
import 'package:qyx/pages/mira_drawer.dart';
import 'package:qyx/pages/main_screen/browser_progress_bar.dart';
import 'package:qyx/pages/main_screen/main_screen_security.dart';

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
              _NavButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                contentColor: contentColor,
                // Gated on real history, not just "a webview exists", so the
                // greyed state actually means "nowhere to go".
                enabled: hasWebView && activeTab.canGoBack,
                onPressed: () =>
                    ref.read(browserChromeProvider).engine?.goBack(),
              ),
              _NavButton(
                icon: Icons.arrow_forward,
                tooltip: 'Forward',
                contentColor: contentColor,
                enabled: hasWebView && activeTab.canGoForward,
                onPressed: () =>
                    ref.read(browserChromeProvider).engine?.goForward(),
              ),
              _NavButton(
                icon: Icons.refresh,
                tooltip: 'Reload',
                contentColor: contentColor,
                enabled: hasWebView,
                onPressed: () =>
                    ref.read(browserChromeProvider).engine?.reload(),
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
              const SizedBox(width: 4),
              // The native title bar is hidden (TitleBarStyle.hidden in main.dart),
              // so the window has no min/max/close affordance without these.
              _WindowControls(color: contentColor),
            ],
          ),
        ),
        BrowserProgressBar(color: accentColor, minHeight: 2),
      ],
    ),
  );
}

// ── Custom window controls (native title bar is hidden) ───────────────────────

class _WindowControls extends StatelessWidget {
  final Color color;
  const _WindowControls({required this.color});

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WinBtn(
          icon: Icons.remove,
          tooltip: 'Minimize',
          color: color,
          onTap: () => windowManager.minimize(),
        ),
        _WinBtn(
          icon: Icons.crop_square_outlined,
          iconSize: 13,
          tooltip: 'Maximize',
          color: color,
          onTap: _toggleMaximize,
        ),
        _WinBtn(
          icon: Icons.close,
          tooltip: 'Close',
          color: color,
          hoverColor: Colors.redAccent,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color? hoverColor;
  final double iconSize;
  final VoidCallback onTap;

  const _WinBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.hoverColor,
    this.iconSize = 16,
  });

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isClose = widget.hoverColor != null;
    final bg = _hover
        ? (isClose
            ? widget.hoverColor!.withValues(alpha: 0.9)
            : widget.color.withValues(alpha: 0.12))
        : Colors.transparent;
    final fg = (_hover && isClose) ? Colors.white : widget.color;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 42,
            height: 30,
            alignment: Alignment.center,
            color: bg,
            child: Icon(widget.icon, size: widget.iconSize, color: fg),
          ),
        ),
      ),
    );
  }
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
  String _lastDomain = '';

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
    if (mounted && !_hasFocus) {
      final newDomain = _domain;
      if (newDomain != _lastDomain) {
        _lastDomain = newDomain;
        setState(() {});
      }
    }
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
                      // Mount the TextField BEFORE asking for focus.
                      //
                      // While showDomain is true the TextField is not in the
                      // tree at all, so urlFocusNode has no attachment and
                      // requestFocus() silently does nothing. _hasFocus then
                      // never flips, showDomain stays true, and the field can
                      // never be reached — the bar is permanently uneditable
                      // once a page has loaded (O-36).
                      //
                      // Flipping _hasFocus ourselves builds the TextField this
                      // frame; the focus request goes in a post-frame callback
                      // so the node has something to attach to by the time it
                      // runs.
                      setState(() => _hasFocus = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        widget.urlFocusNode.requestFocus();
                        widget.urlController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: widget.urlController.text.length,
                        );
                      });
                    },
                    child: Text(
                      _domain,
                      style: jetBrainsMono(
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
                    style: jetBrainsMono(
                        color: widget.contentColor, fontSize: 13),
                    cursorColor: widget.accentColor,
                    decoration: InputDecoration(
                      hintText: isGhost
                          ? 'Private browsing'
                          : 'Search or enter address',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: jetBrainsMono(
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

/// Toolbar icon button with a real disabled state and a pointer hover cue.
///
/// Material's IconButton does highlight on hover, but at this icon size against
/// the dark chrome the default overlay is close to invisible — the toolbar read
/// as inert. This draws an explicit hover pill and dims the icon when disabled,
/// so "greyed" reliably means "no history in that direction".
class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.contentColor,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color contentColor;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: active ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_hovered && active)
                  ? widget.contentColor.withValues(alpha: 0.10)
                  : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: active
                  ? widget.contentColor
                  : widget.contentColor.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
