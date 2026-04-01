import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/browser_service.dart';
import 'package:mira/shell/browser/browser_service_android.dart';
import 'package:mira/shell/browser/browser_service_stub.dart';

final browserServiceProvider = Provider<BrowserService>((ref) {
  if (!kIsWeb && Platform.isAndroid) {
    return AndroidBrowserService();
  }
  return StubBrowserService();
});
