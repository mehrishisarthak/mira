import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/services/download_service.dart';

class DesktopDownloadService implements DownloadService {
  /// Called once when a new download task is created (status: pending).
  /// The owning notifier should prepend this task to its state list.
  final void Function(MiraDownloadTask task) onTaskAdded;

  /// Called whenever an in-progress task changes (status, progress, error).
  /// The owning notifier should apply the updater function to the matching task.
  final void Function(
    String taskId,
    MiraDownloadTask Function(MiraDownloadTask) updater,
  ) onTaskUpdated;

  DesktopDownloadService({
    required this.onTaskAdded,
    required this.onTaskUpdated,
  });

  // ── DownloadService interface ──────────────────────────────────────────────

  @override
  Future<void> startDownload(String url, String filename) async {
    final directory =
        await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final savePath = p.join(directory.path, filename);
    final taskId = const Uuid().v4();

    // Notify the notifier to add a pending entry immediately so the
    // Downloads screen is not blank while the transfer is in flight.
    onTaskAdded(MiraDownloadTask(
      id: taskId,
      url: url,
      filename: filename,
      savePath: savePath,
      status: MiraDownloadStatus.pending,
    ));

    // Run without awaiting — progress updates stream in via onTaskUpdated.
    unawaited(_stream(taskId, url, savePath));
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    // TODO: implement pause for desktop downloads
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    // TODO: implement cancel for desktop downloads
  }

  @override
  Future<void> resumeDownload(String taskId) async {
    // TODO: implement resume for desktop downloads
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
    try {
      final file = File(savePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: Delete error -> $e');
    }
  }

  @override
  Future<void> retryTask(
    String taskId,
    String url,
    String savePath,
    void Function(String id, MiraDownloadTask Function(MiraDownloadTask) fn)
        onUpdate,
  ) async {
    onUpdate(taskId, (t) => t.copyWith(
          status: MiraDownloadStatus.pending,
          progress: 0,
          clearError: true,
        ));
    unawaited(_stream(taskId, url, savePath));
  }

  // ── Private: HttpClient streaming ─────────────────────────────────────────

  Future<void> _stream(
    String taskId,
    String url,
    String savePath, {
    int redirectCount = 0,
  }) async {
    const maxRedirects = 5;
    try {
      onTaskUpdated(
          taskId, (t) => t.copyWith(status: MiraDownloadStatus.running));

      final client = HttpClient();

      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = false; // handle manually for progress accuracy
      request.headers.set(
          HttpHeaders.userAgentHeader, 'Mozilla/5.0 (compatible; MIRABrowser/1.0)');

      final response = await request.close();

      // Manual redirect following
      if (response.isRedirect && redirectCount < maxRedirects) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        client.close();
        if (location != null) {
          await _stream(taskId, location, savePath,
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
          onTaskUpdated(taskId, (t) => t.copyWith(progress: pct));
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      onTaskUpdated(taskId, (t) => t.copyWith(
            status: MiraDownloadStatus.completed,
            progress: 100,
          ));
      debugPrint('MIRA_DOWNLOAD: Complete -> $savePath');
    } catch (e) {
      onTaskUpdated(taskId, (t) => t.copyWith(
            status: MiraDownloadStatus.failed,
            error: e.toString(),
          ));
      debugPrint('MIRA_DOWNLOAD: Error -> $e');
    }
  }
}
