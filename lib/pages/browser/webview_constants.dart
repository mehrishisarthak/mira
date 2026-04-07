import 'dart:collection';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:mira/shell/ad_block/ad_block_service_webview.dart';

/// Shared ad-block user scripts for mounted [InAppWebView]s.
final UnmodifiableListView<UserScript> kBrowserAdBlockUserScripts =
    UnmodifiableListView<UserScript>(AdBlockServiceWebview.initialUserScripts);

const kWebViewSkeletonAutoDismiss = Duration(seconds: 14);
