import 'dart:io';

import 'package:flutter/foundation.dart';

bool browserWebViewSupportsNativeFindInteraction() {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}
