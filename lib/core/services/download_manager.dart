import 'dart:io';
import 'dart:ui'; // Added for IsolateNameServer
import 'dart:isolate'; // Added for SendPort
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

class DownloadManager {
  static const String portName = 'mira_download_port'; // Define a constant name

  static Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await FlutterDownloader.initialize(debug: kDebugMode, ignoreSsl: false);
      FlutterDownloader.registerCallback(downloadCallback, step: 1);
    } catch (e) {
      debugPrint('[MIRA] DownloadManager: init failed -> $e');
    }
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    // 1. Look up the mailbox registered by the main thread
    final SendPort? send = IsolateNameServer.lookupPortByName(portName);
    
    // 2. Package the data into a simple List and send it
    if (send != null) {
      send.send([id, status, progress]);
    } else {
      debugPrint('[MIRA] Warning: SendPort is null. UI is likely closed.');
    }
  }
}