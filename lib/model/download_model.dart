import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

class DownloadManager {
  
  // 1. INITIALIZE (Call this in main.dart)
  static Future<void> init() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
    }
    // No initialization needed for desktop HttpClient
  }

  // 2. THE MAIN FUNCTION
  static Future<void> download(String url, {String? filename}) async {
    debugPrint("Attempting to download: $url");

    if (Platform.isAndroid || Platform.isIOS) {
      // A. Check Permissions
      final hasPermission = await _checkPermission();
      if (!hasPermission) {
        debugPrint("Permission denied.");
        return;
      }

      // B. Get the correct directory
      final directory = await _findLocalPath();
      
      // C. Enqueue the task
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory,
        fileName: filename,
        showNotification: true, 
        openFileFromNotification: true, 
        saveInPublicStorage: true, 
      );
      
      debugPrint("Download task started: $taskId");
    } else if (Platform.isWindows || Platform.isMacOS) {
      await _desktopDownload(url, filename: filename);
    }
  }

  static Future<void> _desktopDownload(String url, {String? filename}) async {
    try {
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final name = filename ?? url.split('/').last.split('?').first;
      final filePath = p.join(directory.path, name);

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final file = File(filePath);
        final raf = file.openSync(mode: FileMode.write);
        await response.pipe(raf as StreamConsumer<List<int>>);
        await raf.close();
        debugPrint("Desktop download complete: $filePath");
      } else {
        debugPrint("Desktop download failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Desktop download error: $e");
    }
  }

  // 3. PERMISSION LOGIC
  static Future<bool> _checkPermission() async {
    if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) return true;

    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;

      if (sdkInt >= 33) {
        return true; 
      }

      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        return result == PermissionStatus.granted;
      }
    }
    return true;
  }

  // 4. PATH FINDER
  static Future<String> _findLocalPath() async {
    Directory? directory;
    try {
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
           directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }
    } catch (e) {
      debugPrint("Path error: $e");
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
    return directory?.path ?? '';
  }
}

class DownloadsNotifier extends StateNotifier<List<DownloadTask>> {
  DownloadsNotifier() : super([]) {
    if (Platform.isAndroid || Platform.isIOS) {
      loadTasks();
    }
  }

  // 1. Load History from Database
  Future<void> loadTasks() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final tasks = await FlutterDownloader.loadTasks();
      if (tasks != null) {
        state = tasks.reversed.toList(); 
      } else {
        state = [];
      }
    }
  }

  // 2. Open File
  Future<void> openTask(DownloadTask task) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (task.status == DownloadTaskStatus.complete) {
        await FlutterDownloader.open(taskId: task.taskId);
      }
    }
  }

  // 3. Delete Task
  Future<void> deleteTask(DownloadTask task) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterDownloader.remove(taskId: task.taskId, shouldDeleteContent: true);
      await loadTasks();
    }
  }
  
  // 4. Retry Failed Task
  Future<void> retryTask(DownloadTask task) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterDownloader.retry(taskId: task.taskId);
      await loadTasks();
    }
  }
}

final downloadsProvider = StateNotifierProvider<DownloadsNotifier, List<DownloadTask>>((ref) {
  return DownloadsNotifier();
});
