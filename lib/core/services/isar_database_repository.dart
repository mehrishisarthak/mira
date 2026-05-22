import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mira/core/services/isar_schemas.dart';
import 'package:mira/core/services/local_database_repository.dart';

/// Concrete implementation of [LocalDatabaseRepository] using Isar.
class IsarHistoryRepository implements LocalDatabaseRepository<HistoryItemSchema> {
  Isar? _isar;

  @override
  Future<void> init() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [HistoryItemSchemaSchema],
      directory: dir.path,
      name: 'history_db',
    );
  }

  @override
  Future<void> put(HistoryItemSchema item) async {
    if (_isar == null) await init();
    await _isar!.writeTxn(() async {
      await _isar!.collection<HistoryItemSchema>().put(item);
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

  @override
  Future<void> init() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [BookmarkSchemaSchema],
      directory: dir.path,
      name: 'bookmarks_db',
    );
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