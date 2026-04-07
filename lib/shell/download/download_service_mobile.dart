import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/services/download_service.dart';

class MobileDownloadService implements DownloadService {
  /// Called after every operation that refreshes the task list
  /// (startDownload, resumeDownload).  The owning notifier should
  /// replace its state with the supplied list.
  final void Function(List<MiraDownloadTask> tasks) onTasksReloaded;

  MobileDownloadService({required this.onTasksReloaded});

  // ── DownloadService interface ──────────────────────────────────────────────

  @override
  Future<void> startDownload(String url, String filename) async {
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      debugPrint('MIRA_DOWNLOAD: Permission denied');
      return;
    }

    final directory = await _findMobilePath();

    await FlutterDownloader.enqueue(
      url: url,
      savedDir: directory,
      fileName: filename,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );

    // Reload so the new task appears immediately in the Downloads screen.
    onTasksReloaded(await loadExistingTasks());
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    try {
      await FlutterDownloader.pause(taskId: taskId);
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: pause failed -> $e');
    }
    onTasksReloaded(await loadExistingTasks());
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    try {
      await FlutterDownloader.cancel(taskId: taskId);
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: cancel failed -> $e');
    }
    onTasksReloaded(await loadExistingTasks());
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    try {
      await FlutterDownloader.resume(taskId: taskId);
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: resume failed -> $e');
    }
    onTasksReloaded(await loadExistingTasks());
  }

  @override
  Future<List<MiraDownloadTask>> loadExistingTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return [];
    return tasks.reversed.map(MiraDownloadTask.fromFlutterTask).toList();
  }

  @override
  Future<void> openTask(MiraDownloadTask task) async {
    await FlutterDownloader.open(taskId: task.id);
  }

  @override
  Future<void> deleteTask(String taskId, String savePath) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
    onTasksReloaded(await loadExistingTasks());
  }

  @override
  Future<void> retryTask(
    String taskId,
    String url,
    String savePath,
    void Function(String id, MiraDownloadTask Function(MiraDownloadTask) fn)
        onUpdate,
  ) async {
    await FlutterDownloader.retry(taskId: taskId);
    onTasksReloaded(await loadExistingTasks());
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<bool> _checkPermission() async {
    if (!Platform.isAndroid) return true;

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 33) return true;

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
    Directory? directory;
    try {
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: Path error -> $e');
      directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    return directory?.path ?? '';
  }
}
