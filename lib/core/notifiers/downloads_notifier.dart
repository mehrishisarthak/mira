import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:qyx/core/entities/download_entity.dart';
import 'package:qyx/core/services/download_service.dart';
import 'package:qyx/core/services/isar_database_repository.dart';

class DownloadsNotifier extends StateNotifier<List<MiraDownloadTask>> {
  final DownloadService _service;
  final IsarDownloadRepository? _isarRepo;

  DownloadsNotifier(this._service, {IsarDownloadRepository? isarRepo})
      : _isarRepo = isarRepo,
        super([]) {
    loadTasks();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _service.dispose();
    super.dispose();
  }

  bool get _isDesktop =>
      !kIsWeb && !Platform.isAndroid && !Platform.isIOS;

  // ── Public callback targets (called by service callbacks) ─────────────────

  /// Prepend a newly-created task to state.
  void addTask(MiraDownloadTask task) {
    if (mounted) state = [task, ...state];
    _schedulePersistDesktopCatalog();
  }

  /// Replace the entire task list (used after mobile reloads).
  void setTasks(List<MiraDownloadTask> tasks) {
    if (mounted) state = tasks;
    _schedulePersistDesktopCatalog();
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
    _schedulePersistDesktopCatalog();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Loads persisted tasks from the platform backend (mobile) or JSON file (desktop).
  Future<void> loadTasks() async {
    if (_isDesktop) {
      await _loadDesktopCatalogIfAny();
      if (state.isNotEmpty) return;
    }
    final tasks = await _service.loadExistingTasks();
    if (tasks.isNotEmpty && mounted) state = tasks;
  }

  // FIXED: Added headers parameter to support authenticated downloads
  Future<void> startDownload(String url, {String? filename, Map<String, String>? headers}) async {
    final name = _resolveFilename(url, filename);
    debugPrint('MIRA_DOWNLOAD: Starting -> $name');
    await _service.startDownload(url, name, headers: headers);
  }

  Future<void> openTask(MiraDownloadTask task) async {
    await _service.openTask(task);
  }

  Future<void> deleteTask(MiraDownloadTask task, {bool deleteFile = false}) async {
    await _service.deleteTask(task.id, task.savePath, deleteFile: deleteFile);
    if (mounted) state = state.where((t) => t.id != task.id).toList();
    _schedulePersistDesktopCatalog();
  }

  Future<void> clearHistory({bool deleteFiles = false}) async {
    if (deleteFiles) {
      // Plug the savePage orphan trap: manually delete files that bypass flutter_downloader
      for (final task in state) {
        try {
          final file = File(task.savePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('MIRA_DOWNLOAD: Orphan cleanup failed for ${task.savePath} -> $e');
        }
      }
    }
    
    await _service.clearHistory(deleteFiles: deleteFiles);
    if (mounted) state = [];
    _schedulePersistDesktopCatalog();
  }

  Future<void> retryTask(MiraDownloadTask task) async {
    // FIXED: Removed the redundant updateTask callback to match the new interface
    await _service.retryTask(task.id, task.url, task.savePath);
  }

  Future<void> pauseTask(MiraDownloadTask task) async {
    await _service.pauseDownload(task.id);
  }

  Future<void> cancelTask(MiraDownloadTask task) async {
    await _service.cancelDownload(task.id);
  }

  Future<void> resumeTask(MiraDownloadTask task) async {
    await _service.resumeDownload(task.id);
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
        _schedulePersistDesktopCatalog();
      }
      debugPrint('MIRA_DOWNLOAD: Page saved -> $savePath');
      return savePath;
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: Save page error -> $e');
      return null;
    }
  }

  // ── Desktop catalog (Isar) ────────────────────────────────────────────────

  Timer? _persistDebounce;

  void _schedulePersistDesktopCatalog() {
    if (!_isDesktop) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_persistDesktopCatalog());
    });
  }

  Future<void> _persistDesktopCatalog() async {
    if (!_isDesktop || !mounted || _isarRepo == null) return;
    try {
      await _isarRepo.saveAll(state);
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: persist desktop -> $e');
    }
  }

  Future<void> _loadDesktopCatalogIfAny() async {
    if (_isarRepo == null) return;
    try {
      final tasks = await _isarRepo.loadAll();
      if (tasks.isNotEmpty && mounted) state = tasks;
    } catch (e) {
      debugPrint('MIRA_DOWNLOAD: restore desktop -> $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _resolveFilename(String url, String? suggested) {
    if (suggested != null && suggested.isNotEmpty) return suggested;
    final segments = Uri.tryParse(url)?.pathSegments ?? [];
    final last = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
    return last.split('?').first.isNotEmpty
        ? last.split('?').first
        : 'download';
  }
}