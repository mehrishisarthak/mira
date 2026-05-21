import 'package:isar/isar.dart';

part 'isar_schemas.g.dart';

@collection
class HistoryItemSchema {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.hash)
  late String url;

  @Index(caseSensitive: false)
  late String title;

  @Index()
  late DateTime timestamp;

  int visitCount = 1;
}

@collection
class BookmarkSchema {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true, type: IndexType.hash)
  late String url;

  @Index(caseSensitive: false)
  late String title;

  @Index()
  late DateTime dateAdded;

  String? folder;
}
