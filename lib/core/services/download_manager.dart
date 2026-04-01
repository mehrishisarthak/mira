import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class DownloadManager {
  static Future<void> init() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await FlutterDownloader.initialize(
        debug: kDebugMode,
        ignoreSsl: false,
      );
    }
  }
}
