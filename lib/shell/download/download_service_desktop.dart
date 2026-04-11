import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/services/download_service.dart';

class _DesktopTransfer {
  _DesktopTransfer({required this.url, required this.savePath, this.headers});
  final String url;
  final String savePath;
  final Map<String, String>? headers; // Holds cookies/auth for this specific chunk stream
  bool pauseRequested = false;
  bool cancelRequested = false;
  HttpClient? client;
  IOSink? sink;
}

class DesktopDownloadService implements DownloadService {
  DesktopDownloadService({
    required this.onTaskAdded,
    required this.onTaskUpdated,
  });

  final void Function(MiraDownloadTask task) onTaskAdded;
  final void Function(
    String taskId,
    MiraDownloadTask Function(MiraDownloadTask) updater,
  ) onTaskUpdated;

  final Map<String, _DesktopTransfer> _active = {};
  final Map<String, String> _urlByTaskId = {};
  final Map<String, String> _pathByTaskId = {};
  final Map<String, Map<String, String>?> _headersByTaskId = {}; // Remembers auth for retries/resumes

  void _removeActive(String taskId) {
    _active.remove(taskId);
  }

  Future<void> _abortTransfer(
    String taskId,
    _DesktopTransfer t, {
    required bool deletePartial,
  }) async {
    try {
      await t.sink?.flush();
    } catch (_) {}
    try {
      await t.sink?.close();
    } catch (_) {}
    try {
      t.client?.close(force: true);
    } catch (_) {}
    if (deletePartial) {
      try {
        final f = File(t.savePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _removeActive(taskId);
  }

  @override
  Future<void> startDownload(String url, String filename, {Map<String, String>? headers}) async {
    final directory =
        await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final savePath = p.join(directory.path, filename);
    final taskId = const Uuid().v4();

    _urlByTaskId[taskId] = url;
    _pathByTaskId[taskId] = savePath;
    _headersByTaskId[taskId] = headers; // Store auth headers for future resumes

    onTaskAdded(MiraDownloadTask(
      id: taskId,
      url: url,
      filename: filename,
      savePath: savePath,
      status: MiraDownloadStatus.pending,
    ));

    _active[taskId] = _DesktopTransfer(url: url, savePath: savePath, headers: headers);
    unawaited(_runDownload(taskId));
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    final t = _active[taskId];
    if (t != null) {
      t.pauseRequested = true;
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    final t = _active[taskId];
    if (t != null) {
      t.cancelRequested = true;
      return;
    }
    
    // FIXED: Maps to the new canceled state instead of failed
    onTaskUpdated(
      taskId,
      (x) {
        if (x.status == MiraDownloadStatus.completed) return x;
        return x.copyWith(
          status: MiraDownloadStatus.canceled,
          progress: 0,
          clearError: true,
        );
      },
    );
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    final url = _urlByTaskId[taskId];
    final path = _pathByTaskId[taskId];
    final headers = _headersByTaskId[taskId];
    
    if (url == null || path == null) return;

    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}

    onTaskUpdated(
      taskId,
      (t) => t.copyWith(
        status: MiraDownloadStatus.pending,
        progress: 0,
        clearError: true,
      ),
    );

    _active[taskId] = _DesktopTransfer(url: url, savePath: path, headers: headers);
    unawaited(_runDownload(taskId));
  }

  @override
  Future<List<MiraDownloadTask>> loadExistingTasks() async {
    return [];
  }

  @override
  Future<void> openTask(MiraDownloadTask task) async {
    final uri = Uri.file(task.savePath);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Future<void> deleteTask(String taskId, String savePath) async {
    final t = _active[taskId];
    if (t != null) {
      await _abortTransfer(taskId, t, deletePartial: true);
    }
    try {
      final file = File(savePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: Delete error -> $e');
    }
    _urlByTaskId.remove(taskId);
    _pathByTaskId.remove(taskId);
    _headersByTaskId.remove(taskId); // Clean up memory
  }

  @override
  Future<void> retryTask(
    String taskId,
    String url,
    String savePath,
  ) async {
    _urlByTaskId[taskId] = url;
    _pathByTaskId[taskId] = savePath;
    final headers = _headersByTaskId[taskId]; // Fetch old auth headers

    // FIXED: Uses the class-level onTaskUpdated instead of a redundant parameter
    onTaskUpdated(
      taskId,
      (t) => t.copyWith(
        status: MiraDownloadStatus.pending,
        progress: 0,
        clearError: true,
      ),
    );
    _active[taskId] = _DesktopTransfer(url: url, savePath: savePath, headers: headers);
    unawaited(_runDownload(taskId));
  }

  Future<void> _runDownload(
    String taskId, {
    int redirectCount = 0,
  }) async {
    const maxRedirects = 5;
    final t = _active[taskId];
    if (t == null) return;

    try {
      if (t.cancelRequested) {
        await _abortTransfer(taskId, t, deletePartial: true);
        onTaskUpdated(
          taskId,
          (x) => x.copyWith(
            status: MiraDownloadStatus.canceled,
            progress: 0,
            clearError: true,
          ),
        );
        return;
      }

      onTaskUpdated(
        taskId,
        (x) => x.copyWith(status: MiraDownloadStatus.running),
      );

      final client = HttpClient();
      t.client = client;

      final request = await client.getUrl(Uri.parse(t.url));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (compatible; MIRABrowser/1.0)',
      );

      // FIXED: Inject the authentication headers if they exist
      if (t.headers != null) {
        t.headers!.forEach((key, value) {
          request.headers.set(key, value);
        });
      }

      final response = await request.close();

      if (t.cancelRequested) {
        await _abortTransfer(taskId, t, deletePartial: true);
        onTaskUpdated(
          taskId,
          (x) => x.copyWith(
            status: MiraDownloadStatus.canceled,
            progress: 0,
            clearError: true,
          ),
        );
        return;
      }

      if (response.isRedirect && redirectCount < maxRedirects) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        client.close();
        _removeActive(taskId);
        if (location != null) {
          _urlByTaskId[taskId] = location;
          _active[taskId] =
              _DesktopTransfer(url: location, savePath: t.savePath, headers: t.headers);
          unawaited(_runDownload(taskId, redirectCount: redirectCount + 1));
        }
        return;
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      final file = File(t.savePath);
      await file.create(recursive: true);
      final sink = file.openWrite();
      t.sink = sink;

      await for (final chunk in response) {
        if (t.cancelRequested) {
          await _abortTransfer(taskId, t, deletePartial: true);
          onTaskUpdated(
            taskId,
            (x) => x.copyWith(
              status: MiraDownloadStatus.canceled,
              progress: 0,
              clearError: true,
            ),
          );
          return;
        }
        if (t.pauseRequested) {
          await _abortTransfer(taskId, t, deletePartial: false);
          onTaskUpdated(
            taskId,
            (x) => x.copyWith(status: MiraDownloadStatus.paused),
          );
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final pct =
              ((receivedBytes / totalBytes) * 100).round().clamp(0, 100);
          onTaskUpdated(taskId, (x) => x.copyWith(progress: pct));
        }
      }

      await sink.flush();
      await sink.close();
      client.close();
      _removeActive(taskId);

      onTaskUpdated(
        taskId,
        (x) => x.copyWith(
          status: MiraDownloadStatus.completed,
          progress: 100,
        ),
      );
      debugPrint('MIRA_DOWNLOAD: Complete -> ${t.savePath}');
    } catch (e) {
      _removeActive(taskId);
      onTaskUpdated(
        taskId,
        (x) => x.copyWith(
          status: MiraDownloadStatus.failed,
          error: e.toString(),
        ),
      );
      debugPrint('MIRA_DOWNLOAD: Error -> $e');
    }
  }
}