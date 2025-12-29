import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DownloadManager {
  
  // 1. INITIALIZE (Call this in main.dart)
  static Future<void> init() async {
    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
    
    // Optional: If we want to update UI progress later, we register a callback here.
    // For now, we rely on the Notification Bar.
  }

  // 2. THE MAIN FUNCTION
  static Future<void> download(String url, {String? filename}) async {
    debugPrint("Attempting to download: $url");

    // A. Check Permissions (The tricky part)
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      debugPrint("Permission denied.");
      return;
    }

    // B. Get the correct directory
    // We want the public 'Downloads' folder so the user can actually find the file.
    final directory = await _findLocalPath();
    
    // C. Enqueue the task
    final taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: directory,
      fileName: filename,
      showNotification: true, // Show progress in status bar
      openFileFromNotification: true, // Click notification to open file
      saveInPublicStorage: true, // REQUIRED for Android 10+ visibility
    );
    
    debugPrint("Download task started: $taskId");
  }

  // 3. PERMISSION LOGIC (READ THIS CAREFULLY)
  static Future<bool> _checkPermission() async {
    if (Platform.isIOS) return true;

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = deviceInfo.version.sdkInt;

    // <--- TRAP: Android 13 (SDK 33) --->
    // Google removed WRITE_EXTERNAL_STORAGE in Android 13.
    // If you ask for it, the OS automatically returns 'Denied' without showing a popup.
    // You essentially "always have" permission to write to your own app limits in Android 13.
    if (sdkInt >= 33) {
      return true; 
    }

    // For Android 12 and below, we must ask explicitly.
    final status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      final result = await Permission.storage.request();
      return result == PermissionStatus.granted;
    }
    return true;
  }

  // 4. PATH FINDER
  static Future<String> _findLocalPath() async {
    Directory? directory;
    try {
      if (Platform.isAndroid) {
        // This gets the public /storage/emulated/0/Download folder
        directory = Directory('/storage/emulated/0/Download');
        // Fallback if that hardcoded path fails (rare)
        if (!await directory.exists()) {
           directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint("Path error: $e");
      directory = await getExternalStorageDirectory();
    }
    return directory?.path ?? '';
  }
}

class DownloadsNotifier extends StateNotifier<List<DownloadTask>> {
  DownloadsNotifier() : super([]) {
    loadTasks();
  }

  // 1. Load History from Database
  Future<void> loadTasks() async {
    // Queries the SQLite db created by flutter_downloader
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null) {
      // Sort: Newest items at the top
      state = tasks.reversed.toList(); 
    } else {
      state = [];
    }
  }

  // 2. Open File
  Future<void> openTask(DownloadTask task) async {
    if (task.status == DownloadTaskStatus.complete) {
      // This tells Android to open the file (e.g. PDF viewer)
      await FlutterDownloader.open(taskId: task.taskId);
    }
  }

  // 3. Delete Task
  Future<void> deleteTask(DownloadTask task) async {
    // 'shouldDeleteContent: true' deletes the actual file from storage too
    await FlutterDownloader.remove(taskId: task.taskId, shouldDeleteContent: true);
    await loadTasks(); // Refresh list to remove the item
  }
  
  // 4. Retry Failed Task
  Future<void> retryTask(DownloadTask task) async {
    await FlutterDownloader.retry(taskId: task.taskId);
    await loadTasks();
  }
}

// THE MISSING PROVIDER DEFINITION
final downloadsProvider = StateNotifierProvider<DownloadsNotifier, List<DownloadTask>>((ref) {
  return DownloadsNotifier();
});