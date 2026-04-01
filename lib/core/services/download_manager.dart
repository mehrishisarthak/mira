import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class DownloadManager {
  static Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await FlutterDownloader.initialize(
        debug: kDebugMode,
        ignoreSsl: false,
      );
      // Register the callback on the background isolate.
      // Must be a static top-level function — not a closure or instance method.
      FlutterDownloader.registerCallback(downloadCallback, step: 1);
    } catch (e) {
      // If the download engine fails to init, the app still launches.
      // Downloads will be unavailable but the browser remains functional.
      debugPrint('[MIRA] DownloadManager: init failed -> $e');
    }
  }

  /// Top-level static callback required by flutter_downloader.
  /// Runs on a background isolate — do NOT access Flutter state here.
  /// The MobileDownloadService reloads tasks from the DB when needed.
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    debugPrint('[MIRA] DownloadCallback: id=$id status=$status progress=$progress');
  }
}
