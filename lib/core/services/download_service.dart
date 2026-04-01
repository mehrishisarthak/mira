import 'package:mira/core/entities/download_entity.dart';

abstract class DownloadService {
  Future<void> startDownload(String url, String filename);
  Future<void> pauseDownload(String taskId);
  Future<void> cancelDownload(String taskId);
  Future<void> resumeDownload(String taskId);
  Future<List<MiraDownloadTask>> loadExistingTasks();

  /// Opens the downloaded file with the system default handler.
  Future<void> openTask(MiraDownloadTask task);

  /// Removes the task from the platform download backend and deletes the file.
  Future<void> deleteTask(String taskId, String savePath);

  /// Retries a failed task.  Implementations decide whether to resume an
  /// existing platform task or enqueue a fresh one.
  Future<void> retryTask(
    String taskId,
    String url,
    String savePath,
    void Function(String id, MiraDownloadTask Function(MiraDownloadTask) fn)
        onUpdate,
  );
}
