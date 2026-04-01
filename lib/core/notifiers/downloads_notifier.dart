import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/services/download_service.dart';

class DownloadsNotifier extends StateNotifier<List<MiraDownloadTask>> {
  final DownloadService _service;

  DownloadsNotifier(this._service) : super([]) {
    loadTasks();
  }

  // ── Public callback targets (called by service callbacks) ─────────────────

  /// Prepend a newly-created task to state.
  void addTask(MiraDownloadTask task) {
    if (mounted) state = [task, ...state];
  }

  /// Replace the entire task list (used after mobile reloads).
  void setTasks(List<MiraDownloadTask> tasks) {
    if (mounted) state = tasks;
  }

  /// Apply an updater function to a single in-flight task.
  void updateTask(
      String id, MiraDownloadTask Function(MiraDownloadTask) updater) {
    if (!mounted) return;
    final idx = state.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = [...state];
    updated[idx] = updater(updated[idx]);
    state = updated;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Loads persisted tasks from the platform backend (no-op on desktop).
  Future<void> loadTasks() async {
    final tasks = await _service.loadExistingTasks();
    if (tasks.isNotEmpty && mounted) state = tasks;
  }

  Future<void> startDownload(String url, {String? filename}) async {
    final name = _resolveFilename(url, filename);
    debugPrint('MIRA_DOWNLOAD: Starting -> $name');
    await _service.startDownload(url, name);
  }

  Future<void> openTask(MiraDownloadTask task) async {
    await _service.openTask(task);
  }

  Future<void> deleteTask(MiraDownloadTask task) async {
    await _service.deleteTask(task.id, task.savePath);
    if (mounted) state = state.where((t) => t.id != task.id).toList();
  }

  Future<void> retryTask(MiraDownloadTask task) async {
    await _service.retryTask(task.id, task.url, task.savePath, updateTask);
  }

  /// Saves an already-fetched [html] string to the downloads folder and adds
  /// a completed entry so it appears in the Downloads screen immediately.
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _resolveFilename(String url, String? suggested) {
    if (suggested != null && suggested.isNotEmpty) return suggested;
    final segments = Uri.tryParse(url)?.pathSegments ?? [];
    final last = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
    return last.split('?').first.isNotEmpty
        ? last.split('?').first
        : 'download';
  }
}
