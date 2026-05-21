import 'dart:async';

/// A generic interface for asynchronous local database operations.
/// This decouples the business logic from the specific database implementation (Isar/Drift).
abstract class LocalDatabaseRepository<T> {
  /// Initialize the database and its schemas.
  Future<void> init();

  /// Adds or updates an item in the database.
  Future<void> put(T item);

  /// Bulk add/update items.
  Future<void> putAll(List<T> items);

  /// Deletes an item by its unique ID.
  Future<void> delete(int id);

  /// Clears all items in the collection/table.
  Future<void> clear();

  /// Fetches all items, optionally sorted and limited.
  Future<List<T>> getAll({bool descending = true, int? limit});

  /// Searches for items matching a query string.
  Future<List<T>> search(String query);

  /// Provides a real-time stream of all items in the collection.
  Stream<List<T>> watchAll();
}
