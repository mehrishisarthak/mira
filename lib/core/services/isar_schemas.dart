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

@collection
class DownloadRecordSchema {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.hash, unique: true)
  late String taskId;

  late String url;
  late String filename;
  late String savePath;
  late String statusName;
  int progress = 0;
  String? error;

  @Index()
  int sortOrder = 0;
}
