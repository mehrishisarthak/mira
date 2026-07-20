import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qyx/core/entities/download_entity.dart';
import 'package:qyx/core/services/isar_schemas.dart';
import 'package:qyx/core/services/local_database_repository.dart';

/// Concrete implementation of [LocalDatabaseRepository] using Isar.
class IsarHistoryRepository implements LocalDatabaseRepository<HistoryItemSchema> {
  Isar? _isar;
  Future<void>? _initFuture;

  // Guarded by a shared future so two concurrent first-callers don't both reach
  // Isar.open (which throws on a duplicate instance name). Reset to null on
  // failure so a transient error (e.g. a locked file) stays retryable rather
  // than caching a permanently-failed future.
  @override
  Future<void> init() => _initFuture ??= _open();

  Future<void> _open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [HistoryItemSchemaSchema],
        directory: dir.path,
        name: 'history_db',
      );
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  @override
  Future<void> put(HistoryItemSchema item) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<HistoryItemSchema>().put(item);
    });
  }

  /// Upserts a history entry by URL.
  /// If an entry for this URL exists within [dedupeWindow], updates its title
  /// and timestamp instead of inserting a duplicate.
  Future<void> upsertByUrl(
    String url,
    String title, {
    Duration dedupeWindow = const Duration(minutes: 30),
  }) async {
    if (_isar == null) await init();
    final cutoff = DateTime.now().subtract(dedupeWindow);
    await _isar!.writeTxn(() async {
      final existing = await _isar!
          .collection<HistoryItemSchema>()
          .filter()
          .urlEqualTo(url)
          .timestampGreaterThan(cutoff)
          .sortByTimestampDesc()
          .findFirst();
      if (existing != null) {
        existing.title = title;
        existing.timestamp = DateTime.now();
        existing.visitCount += 1;
        await _isar!.collection<HistoryItemSchema>().put(existing);
      } else {
        final item = HistoryItemSchema()
          ..url = url
          ..title = title
          ..timestamp = DateTime.now()
          ..visitCount = 1;
        await _isar!.collection<HistoryItemSchema>().put(item);
      }
    });
  }

  @override
  Future<void> putAll(List<HistoryItemSchema> items) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<HistoryItemSchema>().putAll(items);
    });
  }

  @override
  Future<void> delete(int id) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<HistoryItemSchema>().delete(id);
    });
  }

  @override
  Future<void> clear() async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<HistoryItemSchema>().clear();
    });
  }

  @override
  Future<List<HistoryItemSchema>> getAll({bool descending = true, int? limit}) async {
    if (_isar == null) await init();
    var query = _isar!.collection<HistoryItemSchema>().where();
    
    if (descending) {
      return await query.sortByTimestampDesc().limit(limit ?? 1000).findAll();
    } else {
      return await query.sortByTimestamp().limit(limit ?? 1000).findAll();
    }
  }

  @override
  Future<List<HistoryItemSchema>> search(String query) async {
    if (_isar == null) await init();
    return await _isar!.collection<HistoryItemSchema>()
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .urlContains(query, caseSensitive: false)
        .sortByTimestampDesc()
        .findAll();
  }

  @override
  Stream<List<HistoryItemSchema>> watchAll() {
    if (_isar == null) {
      // Fallback for watchAll if not initialized yet
      return Stream.fromFuture(init()).asyncExpand((_) => _isar!.collection<HistoryItemSchema>()
          .where()
          .sortByTimestampDesc()
          .watch(fireImmediately: true));
    }
    return _isar!.collection<HistoryItemSchema>()
        .where()
        .sortByTimestampDesc()
        .watch(fireImmediately: true);
  }
}

/// Concrete implementation of [LocalDatabaseRepository] using Isar.
class IsarBookmarkRepository implements LocalDatabaseRepository<BookmarkSchema> {
  Isar? _isar;
  Future<void>? _initFuture;

  // See IsarHistoryRepository.init — shared-future guard against the concurrent
  // double-open race; reset on failure so transient errors stay retryable.
  @override
  Future<void> init() => _initFuture ??= _open();

  Future<void> _open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [BookmarkSchemaSchema],
        directory: dir.path,
        name: 'bookmarks_db',
      );
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  @override
  Future<void> put(BookmarkSchema item) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<BookmarkSchema>().put(item);
    });
  }

  @override
  Future<void> putAll(List<BookmarkSchema> items) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<BookmarkSchema>().putAll(items);
    });
  }

  @override
  Future<void> delete(int id) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<BookmarkSchema>().delete(id);
    });
  }

  @override
  Future<void> clear() async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<BookmarkSchema>().clear();
    });
  }

  @override
  Future<List<BookmarkSchema>> getAll({bool descending = true, int? limit}) async {
    if (_isar == null) await init();
    var query = _isar!.collection<BookmarkSchema>().where();
    
    if (descending) {
      return await query.sortByDateAddedDesc().limit(limit ?? 1000).findAll();
    } else {
      return await query.sortByDateAdded().limit(limit ?? 1000).findAll();
    }
  }

  @override
  Future<List<BookmarkSchema>> search(String query) async {
    if (_isar == null) await init();
    return await _isar!.collection<BookmarkSchema>()
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .urlContains(query, caseSensitive: false)
        .sortByDateAddedDesc()
        .findAll();
  }

  @override
  Stream<List<BookmarkSchema>> watchAll() {
    if (_isar == null) {
      return Stream.fromFuture(init()).asyncExpand((_) => _isar!.collection<BookmarkSchema>()
          .where()
          .sortByDateAddedDesc()
          .watch(fireImmediately: true));
    }
    return _isar!.collection<BookmarkSchema>()
        .where()
        .sortByDateAddedDesc()
        .watch(fireImmediately: true);
  }
}

class IsarDownloadRepository {
  Isar? _isar;
  Future<void>? _initFuture;

  // See IsarHistoryRepository.init — shared-future guard against the concurrent
  // double-open race; reset on failure so transient errors stay retryable.
  Future<void> init() => _initFuture ??= _open();

  Future<void> _open() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _isar = await Isar.open(
        [DownloadRecordSchemaSchema],
        directory: dir.path,
        name: 'downloads_db',
      );
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> saveAll(List<MiraDownloadTask> tasks) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      final existingRecords = await _isar!.collection<DownloadRecordSchema>().where().findAll();
      final existingMap = {for (var r in existingRecords) r.taskId: r};

      await _isar!.collection<DownloadRecordSchema>().clear();
      await _isar!.collection<DownloadRecordSchema>().putAll(
        tasks.asMap().entries.map((e) {
          final existing = existingMap[e.value.id];
          return DownloadRecordSchema()
            ..taskId = e.value.id
            ..url = e.value.url
            ..filename = e.value.filename
            ..savePath = e.value.savePath
            ..statusName = e.value.status.name
            ..progress = e.value.progress
            ..error = e.value.error
            ..sortOrder = e.key
            ..timestamp = e.value.timestamp ?? existing?.timestamp
            ..fileSizeString = e.value.fileSizeString ?? existing?.fileSizeString;
        }).toList(),
      );
    });
  }

  Future<List<MiraDownloadTask>> loadAll() async {
    if (_isar == null) await init();
    final records = await _isar!.collection<DownloadRecordSchema>().where().findAll();
    records.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return records.map((r) => MiraDownloadTask(
      id: r.taskId,
      url: r.url,
      filename: r.filename,
      savePath: r.savePath,
      status: MiraDownloadStatus.values.firstWhere(
        (s) => s.name == r.statusName,
        orElse: () => MiraDownloadStatus.completed,
      ),
      progress: r.progress,
      error: r.error,
      timestamp: r.timestamp,
      fileSizeString: r.fileSizeString,
    )).toList();
  }

  Future<void> updateMetadata(String taskId, {String? fileSizeString}) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      final record = await _isar!.collection<DownloadRecordSchema>().getByTaskId(taskId);
      if (record != null) {
        if (fileSizeString != null) record.fileSizeString = fileSizeString;
        await _isar!.collection<DownloadRecordSchema>().put(record);
      }
    });
  }
}