import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

// ── UNIFIED MODEL ─────────────────────────────────────────────────────────────

enum MiraDownloadStatus { pending, running, completed, failed }

class MiraDownloadTask {
  final String id;
  final String url;
  final String filename;
  final String savePath;
  final MiraDownloadStatus status;
  final int progress; // 0-100
  final String? error;

  const MiraDownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.savePath,
    required this.status,
    this.progress = 0,
    this.error,
  });

  MiraDownloadTask copyWith({
    MiraDownloadStatus? status,
    int? progress,
    String? error,
    bool clearError = false,
  }) {
    return MiraDownloadTask(
      id: id,
      url: url,
      filename: filename,
      savePath: savePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Converts a flutter_downloader DownloadTask to MiraDownloadTask.
  /// Only called on Android/iOS where flutter_downloader is active.
  static MiraDownloadTask fromFlutterTask(DownloadTask task) {
    final MiraDownloadStatus status;
    if (task.status == DownloadTaskStatus.complete) {
      status = MiraDownloadStatus.completed;
    } else if (task.status == DownloadTaskStatus.failed ||
        task.status == DownloadTaskStatus.canceled) {
      status = MiraDownloadStatus.failed;
    } else if (task.status == DownloadTaskStatus.running ||
        task.status == DownloadTaskStatus.enqueued) {
      status = MiraDownloadStatus.running;
    } else {
      status = MiraDownloadStatus.pending;
    }

    return MiraDownloadTask(
      id: task.taskId,
      url: task.url,
      filename: task.filename ?? 'download',
      savePath: p.join(task.savedDir, task.filename ?? ''),
      status: status,
      progress: task.progress,
    );
  }
}

// ── DOWNLOAD MANAGER (init only) ──────────────────────────────────────────────

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

// ── NOTIFIER ──────────────────────────────────────────────────────────────────

class DownloadsNotifier extends StateNotifier<List<MiraDownloadTask>> {
  DownloadsNotifier() : super([]) {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      loadTasks();
    }
  }

  // ── LOAD ────────────────────────────────────────────────────────────────────

  /// Refreshes the task list.
  /// On mobile: loads from flutter_downloader's database.
  /// On desktop: state is managed in-memory; this is a no-op.
  Future<void> loadTasks() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final tasks = await FlutterDownloader.loadTasks();
      if (tasks != null) {
        state = tasks.reversed.map(MiraDownloadTask.fromFlutterTask).toList();
      } else {
        state = [];
      }
    }
  }

  // ── START ────────────────────────────────────────────────────────────────────

  Future<void> startDownload(String url, {String? filename}) async {
    final name = _resolveFilename(url, filename);
    debugPrint('MIRA_DOWNLOAD: Starting -> $name');

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _mobileDownload(url, name);
    } else if (!kIsWeb) {
      await _desktopDownload(url, name);
    }
  }

  // ── MOBILE BACKEND ──────────────────────────────────────────────────────────

  Future<void> _mobileDownload(String url, String name) async {
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      debugPrint('MIRA_DOWNLOAD: Permission denied');
      return;
    }

    final directory = await _findMobilePath();

    await FlutterDownloader.enqueue(
      url: url,
      savedDir: directory,
      fileName: name,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );

    // Reload so the new task appears immediately in the downloads screen.
    await loadTasks();
  }

  // ── DESKTOP BACKEND ─────────────────────────────────────────────────────────

  Future<void> _desktopDownload(String url, String name) async {
    final directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final savePath = p.join(directory.path, name);
    final taskId = const Uuid().v4();

    // Add task immediately so the Downloads screen shows something right away.
    state = [
      MiraDownloadTask(
        id: taskId,
        url: url,
        filename: name,
        savePath: savePath,
        status: MiraDownloadStatus.pending,
      ),
      ...state,
    ];

    // Run without awaiting — progress streams in via _updateTask.
    unawaited(_streamDesktopDownload(taskId, url, savePath));
  }

  Future<void> _streamDesktopDownload(
      String taskId, String url, String savePath,
      {int redirectCount = 0}) async {
    const maxRedirects = 5;
    try {
      _updateTask(taskId, (t) => t.copyWith(status: MiraDownloadStatus.running));

      final client = HttpClient();

      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = false; // handle manually for progress accuracy
      request.headers.set(HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (compatible; MIRABrowser/1.0)');

      final response = await request.close();

      // Manual redirect following
      if (response.isRedirect &&
          redirectCount < maxRedirects) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        client.close();
        if (location != null) {
          await _streamDesktopDownload(taskId, location, savePath,
              redirectCount: redirectCount + 1);
          return;
        }
      }

      final totalBytes = response.contentLength; // -1 when unknown
      int receivedBytes = 0;

      final file = File(savePath);
      await file.create(recursive: true);
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final pct =
              ((receivedBytes / totalBytes) * 100).round().clamp(0, 100);
          _updateTask(taskId, (t) => t.copyWith(progress: pct));
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      _updateTask(taskId, (t) => t.copyWith(
            status: MiraDownloadStatus.completed,
            progress: 100,
          ));
      debugPrint('MIRA_DOWNLOAD: Complete -> $savePath');
    } catch (e) {
      _updateTask(taskId, (t) => t.copyWith(
            status: MiraDownloadStatus.failed,
            error: e.toString(),
          ));
      debugPrint('MIRA_DOWNLOAD: Error -> $e');
    }
  }

  // ── ACTIONS ─────────────────────────────────────────────────────────────────

  Future<void> openTask(MiraDownloadTask task) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await FlutterDownloader.open(taskId: task.id);
    } else {
      final uri = Uri.file(task.savePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> deleteTask(MiraDownloadTask task) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await FlutterDownloader.remove(
          taskId: task.id, shouldDeleteContent: true);
      await loadTasks();
    } else {
      try {
        final file = File(task.savePath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('MIRA_DOWNLOAD: Delete error -> $e');
      }
      if (mounted) state = state.where((t) => t.id != task.id).toList();
    }
  }

  /// Saves an already-fetched [html] string to the downloads folder and adds
  /// a completed entry to state so it appears in the Downloads screen.
  Future<String?> savePage(String html, String filename) async {
    try {
      final directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final savePath = p.join(directory.path, filename);
      await File(savePath).writeAsString(html, flush: true);

      if (mounted) {
        state = [
          MiraDownloadTask(
            id: const Uuid().v4(),
            url: '',
            filename: filename,
            savePath: savePath,
            status: MiraDownloadStatus.completed,
            progress: 100,
          ),
          ...state,
        ];
      }
      debugPrint('MIRA_DOWNLOAD: Page saved -> $savePath');
      return savePath;
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: Save page error -> $e');
      return null;
    }
  }

  Future<void> retryTask(MiraDownloadTask task) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await FlutterDownloader.retry(taskId: task.id);
      await loadTasks();
    } else {
      _updateTask(task.id,
          (t) => t.copyWith(
                status: MiraDownloadStatus.pending,
                progress: 0,
                clearError: true,
              ));
      unawaited(_streamDesktopDownload(task.id, task.url, task.savePath));
    }
  }

  // ── INTERNAL HELPERS ────────────────────────────────────────────────────────

  void _updateTask(
      String id, MiraDownloadTask Function(MiraDownloadTask) updater) {
    if (!mounted) return;
    final idx = state.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = [...state];
    updated[idx] = updater(updated[idx]);
    state = updated;
  }

  static String _resolveFilename(String url, String? suggested) {
    if (suggested != null && suggested.isNotEmpty) return suggested;
    final segments = Uri.tryParse(url)?.pathSegments ?? [];
    final last = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
    return last.split('?').first.isNotEmpty
        ? last.split('?').first
        : 'download';
  }

  static Future<bool> _checkPermission() async {
    if (!Platform.isAndroid) return true;

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 33) return true;

    final status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      final result = await Permission.storage.request();
      return result == PermissionStatus.granted;
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

// ── PROVIDER ──────────────────────────────────────────────────────────────────

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<MiraDownloadTask>>((ref) {
  return DownloadsNotifier();
});
