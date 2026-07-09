import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path/path.dart' as p;

// ── UNIFIED MODEL ─────────────────────────────────────────────────────────────

enum MiraDownloadStatus { pending, running, completed, failed, paused, canceled }

class MiraDownloadTask {
  final String id;
  final String url;
  final String filename;
  final String savePath;
  final MiraDownloadStatus status;
  final int progress; // 0-100
  final String? error;
  final DateTime? timestamp;
  final String? fileSizeString;

  const MiraDownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.savePath,
    required this.status,
    this.progress = 0,
    this.error,
    this.timestamp,
    this.fileSizeString,
  });

  MiraDownloadTask copyWith({
    MiraDownloadStatus? status,
    int? progress,
    String? error,
    bool clearError = false,
    DateTime? timestamp,
    String? fileSizeString,
  }) {
    return MiraDownloadTask(
      id: id,
      url: url,
      filename: filename,
      savePath: savePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      timestamp: timestamp ?? this.timestamp,
      fileSizeString: fileSizeString ?? this.fileSizeString,
    );
  }

  static MiraDownloadTask fromFlutterTask(DownloadTask task) {
    final MiraDownloadStatus status;
    
    if (task.status == DownloadTaskStatus.complete) {
      status = MiraDownloadStatus.completed;
    } else if (task.status == DownloadTaskStatus.canceled) {
      status = MiraDownloadStatus.canceled;
    } else if (task.status == DownloadTaskStatus.failed) {
      status = MiraDownloadStatus.failed;
    } else if (task.status == DownloadTaskStatus.running ||
        task.status == DownloadTaskStatus.enqueued) {
      status = MiraDownloadStatus.running;
    } else if (task.status == DownloadTaskStatus.paused) {
      status = MiraDownloadStatus.paused;
    } else {
      status = MiraDownloadStatus.pending;
    }

    // 3. FIXED THE NULL FILENAME TRAP
    final safeFilename = task.filename ?? 'download';

    return MiraDownloadTask(
      id: task.taskId,
      url: task.url,
      filename: safeFilename,
      savePath: p.join(task.savedDir, safeFilename), // Now safely uses the fallback
      status: status,
      progress: task.progress,
      timestamp: DateTime.fromMillisecondsSinceEpoch(task.timeCreated),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'filename': filename,
        'savePath': savePath,
        'status': status.name,
        'progress': progress,
        'error': error,
        'timestamp': timestamp?.millisecondsSinceEpoch,
        'fileSizeString': fileSizeString,
      };

  static MiraDownloadTask fromJson(Map<String, dynamic> m) {
    // 4. FIXED ZOMBIE TASKS: Throw an error if the URL is completely missing so the Notifier can self-heal
    final String? parsedUrl = m['url'] as String?;
    if (parsedUrl == null || parsedUrl.isEmpty) {
      throw const FormatException('Missing URL in downloaded task JSON');
    }

    return MiraDownloadTask(
      id: m['id'] as String,
      url: parsedUrl,
      filename: m['filename'] as String? ?? 'download',
      savePath: m['savePath'] as String? ?? '',
      status: MiraDownloadStatus.values.byName(m['status'] as String? ?? 'pending'),
      progress: (m['progress'] as num?)?.toInt() ?? 0,
      error: m['error'] as String?,
      timestamp: m['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int) : null,
      fileSizeString: m['fileSizeString'] as String?,
    );
  }
}