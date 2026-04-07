import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/services/download_provider.dart';

/// Link context UI (desktop popup + mobile bottom sheet).
class BrowserLinkContextMenu {
  BrowserLinkContextMenu._();

  static void show(
    BuildContext context,
    WidgetRef ref,
    String linkUrl, {
    Offset? pointerPosition,
  }) {
    if (!context.mounted) return;
    final theme = ref.read(themeProvider);
    final isGhost = ref.read(isGhostModeProvider);
    final isLight = theme.mode == ThemeMode.light;
    final textColor = isLight ? kMiraInkPrimary : Colors.white;

    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktop) {
      _showDesktopPopup(
        context,
        ref,
        linkUrl,
        theme,
        isGhost,
        textColor,
        pointerPosition,
      );
    } else {
      _showMobileSheet(context, ref, linkUrl, theme, isGhost, textColor);
    }
  }

  static void _showDesktopPopup(
    BuildContext context,
    WidgetRef ref,
    String linkUrl,
    dynamic theme,
    bool isGhost,
    Color textColor,
    Offset? pointerPosition,
  ) {
    final overlayBox =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final position = pointerPosition ??
        overlayBox?.localToGlobal(Offset.zero) ??
        Offset.zero;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: theme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            linkUrl.length > 60 ? '${linkUrl.substring(0, 60)}…' : linkUrl,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.5),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'copy',
          child: Row(children: [
            Icon(Icons.copy, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Copy Link', style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'newtab',
          child: Row(children: [
            Icon(Icons.tab_outlined, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Open in New Tab',
                style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'external',
          child: Row(children: [
            Icon(Icons.open_in_browser, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Open in External Browser',
                style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'download',
          child: Row(children: [
            Icon(Icons.download_outlined, color: textColor, size: 18),
            const SizedBox(width: 10),
            Text('Download Link',
                style: TextStyle(color: textColor, fontSize: 13)),
          ]),
        ),
      ],
    ).then((action) {
      if (action == null || !context.mounted) return;
      switch (action) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: linkUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied')),
          );
          break;
        case 'newtab':
          if (isGhost) {
            ref.read(ghostTabsProvider.notifier).addTab(url: linkUrl);
          } else {
            ref.read(tabsProvider.notifier).addTab(url: linkUrl);
          }
          break;
        case 'external':
          final uri = Uri.tryParse(linkUrl);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          break;
        case 'download':
          ref.read(downloadsProvider.notifier).startDownload(linkUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download started'),
              backgroundColor: Colors.blueAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
      }
    });
  }

  static void _showMobileSheet(
    BuildContext context,
    WidgetRef ref,
    String linkUrl,
    dynamic theme,
    bool isGhost,
    Color textColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  linkUrl,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.copy, color: textColor),
              title: Text('Copy Link', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: linkUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.tab_outlined, color: textColor),
              title:
                  Text('Open in New Tab', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                HapticFeedback.lightImpact();
                if (isGhost) {
                  ref.read(ghostTabsProvider.notifier).addTab(url: linkUrl);
                } else {
                  ref.read(tabsProvider.notifier).addTab(url: linkUrl);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_browser, color: textColor),
              title: Text('Open in External Browser',
                  style: TextStyle(color: textColor)),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(linkUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.download_outlined, color: textColor),
              title:
                  Text('Download Link', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
                ref.read(downloadsProvider.notifier).startDownload(linkUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download started'),
                    backgroundColor: Colors.blueAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
