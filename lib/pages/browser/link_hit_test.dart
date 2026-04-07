import 'package:flutter_inappwebview/flutter_inappwebview.dart';

bool webViewHitIsLink(InAppWebViewHitTestResultType? type) {
  return type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE ||
      type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE;
}
