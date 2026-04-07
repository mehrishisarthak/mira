import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'link_hit_test.dart';
import 'webview_session.dart';

/// Desktop / WebView2: right-click raises [ContextMenu.onCreateContextMenu].
ContextMenu? buildDesktopLinkContextMenu(WebViewSession session,
    void Function(String url) onShowLinkMenu) {
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) return null;
  return session.cachedDesktopContextMenu ??= ContextMenu(
    settings: ContextMenuSettings(
      hideDefaultSystemContextMenuItems: false,
    ),
    onCreateContextMenu: (hitTestResult) {
      final url = hitTestResult.extra;
      if (url != null &&
          url.isNotEmpty &&
          webViewHitIsLink(hitTestResult.type)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onShowLinkMenu(url);
        });
      }
    },
  );
}
