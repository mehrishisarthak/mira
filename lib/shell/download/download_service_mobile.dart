import 'dart:io';
import 'dart:isolate'; // Added for ReceivePort
import 'dart:ui'; // Added for IsolateNameServer

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mira/core/app_globals.dart';
import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/services/download_service.dart';

class MobileDownloadService implements DownloadService {
  /// Reloads the entire list (useful when adding/deleting tasks)
  final void Function(List<MiraDownloadTask> tasks) onTasksReloaded;
  
  /// Granular update for a single task (perfect for progress bars)
  final void Function(String id, MiraDownloadTask Function(MiraDownloadTask) updater) onTaskUpdated;

  final ReceivePort _port = ReceivePort();

  MobileDownloadService({
    required this.onTasksReloaded,
    required this.onTaskUpdated,
  }) {
    _bindBackgroundIsolate();
  }

  // ── Isolate Communication Bridge ──────────────────────────────────────────

  void _bindBackgroundIsolate() {
    // 1. Clean up any zombie ports from hot restarts
    IsolateNameServer.removePortNameMapping('mira_download_port');

    // 2. Register the UI's mailbox
    IsolateNameServer.registerPortWithName(_port.sendPort, 'mira_download_port');

    // 3. Listen for background chunks
    _port.listen((dynamic data) {
      final String id = data[0];
      final int statusInt = data[1];
      final int progress = data[2];

      final fdStatus = DownloadTaskStatus.fromInt(statusInt);
      final miraStatus = _mapStatus(fdStatus);

      // Tell Riverpod to update JUST this specific task
      onTaskUpdated(id, (oldTask) => oldTask.copyWith(
            status: miraStatus,
            progress: progress,
          ));
    });
  }

  MiraDownloadStatus _mapStatus(DownloadTaskStatus status) {
    if (status == DownloadTaskStatus.complete) return MiraDownloadStatus.completed;
    // FIXED: Canceled now has its own distinct UI state
    if (status == DownloadTaskStatus.canceled) return MiraDownloadStatus.canceled;
    if (status == DownloadTaskStatus.failed) return MiraDownloadStatus.failed;
    if (status == DownloadTaskStatus.running || status == DownloadTaskStatus.enqueued) return MiraDownloadStatus.running;
    if (status == DownloadTaskStatus.paused) return MiraDownloadStatus.paused;
    return MiraDownloadStatus.pending;
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('mira_download_port');
    _port.close();
  }

  // ── DownloadService interface ──────────────────────────────────────────────

  @override
  Future<void> startDownload(String url, String filename, {Map<String, String>? headers}) async {
    try {
      final hasPermission = await _checkPermission();
      if (!hasPermission) {
        debugPrint('MIRA_DOWNLOAD: Permission denied');
        return;
      }

      final directory = await _findMobilePath();
      if (directory.isEmpty) {
        debugPrint('MIRA_DOWNLOAD: Could not resolve a writable download directory');
        return;
      }

      await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory,
        fileName: filename,
        headers: headers ?? {},
        showNotification: true,
        openFileFromNotification: true,
      );

      onTasksReloaded(await loadExistingTasks());
    } catch (e, st) {
      debugPrint('MIRA_DOWNLOAD: startDownload failed -> $e\n$st');
    }
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    try {
      await FlutterDownloader.pause(taskId: taskId);
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: pause failed -> $e');
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    try {
      await FlutterDownloader.cancel(taskId: taskId);
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: cancel failed -> $e');
    }
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    try {
      await FlutterDownloader.resume(taskId: taskId);
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: resume failed -> $e');
    }
  }

  @override
  Future<List<MiraDownloadTask>> loadExistingTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return [];
    return tasks.reversed.map(MiraDownloadTask.fromFlutterTask).toList();
  }

  @override
  Future<void> openTask(MiraDownloadTask task) async {
    // Open by file path, not taskId: FlutterDownloader.open silently returns
    // false on modern Android and can't open saved-page entries (which have no
    // real download task). open_filex handles the FileProvider + intent + MIME.
    final result = await OpenFilex.open(task.savePath);
    if (result.type != ResultType.done) {
      debugPrint(
          'MIRA_DOWNLOAD: open failed (${result.type}) -> ${result.message}');
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(_openErrorMessage(result.type))),
      );
    }
  }

  static String _openErrorMessage(ResultType type) {
    switch (type) {
      case ResultType.noAppToOpen:
        return 'No app can open this file';
      case ResultType.fileNotFound:
        return 'File not found';
      case ResultType.permissionDenied:
        return 'Permission denied opening file';
      default:
        return "Couldn't open file";
    }
  }

  @override
  Future<void> deleteTask(String taskId, String savePath) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    // Reload UI to remove the task from the screen
    onTasksReloaded(await loadExistingTasks());
  }

  @override
  Future<void> retryTask(
    String taskId,
    String url,
    String savePath,
  ) async {
    // FIXED: Removed the redundant onUpdate parameter to match the interface
    await FlutterDownloader.retry(taskId: taskId);
    // Just like startDownload, we reload to ensure the new ID/Task is in the Riverpod list
    onTasksReloaded(await loadExistingTasks());
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<bool> _checkPermission() async {
    if (!Platform.isAndroid) return true;

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 33) {
      // POST_NOTIFICATIONS gates the progress notification only, not the
      // download. Request it, but never block the download on the result.
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        debugPrint('MIRA_DOWNLOAD: notification permission not granted — '
            'download will run without a progress notification');
      }
      return true;
    }

    var status = await Permission.storage.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }
    return true;
  }

  static Future<String> _findMobilePath() async {
    try {
      if (Platform.isIOS) {
        return (await getApplicationDocumentsDirectory()).path;
      }
      // Android: getDownloadsDirectory() maps to Environment.DIRECTORY_DOWNLOADS
      // and is accessible without MANAGE_EXTERNAL_STORAGE on all API levels.
      final dl = await getDownloadsDirectory();
      if (dl != null) return dl.path;

      // Fallback: app-private external storage (always accessible)
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext.path;
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: Path resolution error -> $e');
    }
    // Last resort: always-writable internal directory
    return (await getApplicationDocumentsDirectory()).path;
  }
}