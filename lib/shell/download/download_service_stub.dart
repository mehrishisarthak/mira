import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/services/download_service.dart';

class StubDownloadService implements DownloadService {
  @override
  // FIXED: Added the headers parameter to match the new interface
  Future<void> startDownload(String url, String filename, {Map<String, String>? headers}) {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }

  @override
  Future<void> pauseDownload(String taskId) {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }

  @override
  Future<void> cancelDownload(String taskId) {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }

  @override
  Future<void> resumeDownload(String taskId) {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }

  @override
  Future<List<MiraDownloadTask>> loadExistingTasks() {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }

  @override
  Future<void> openTask(MiraDownloadTask task) {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }

  @override
  Future<void> deleteTask(String taskId, String savePath) {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }

  @override
  // FIXED: Removed the redundant onUpdate parameter to match the new interface
  Future<void> retryTask(
    String taskId,
    String url,
    String savePath,
  ) {
    throw UnimplementedError(
        'DownloadService is not supported on this platform.');
  }
}