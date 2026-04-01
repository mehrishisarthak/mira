import 'package:flutter_downloader/flutter_downloader.dart';
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
