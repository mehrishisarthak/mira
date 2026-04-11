import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/notifiers/downloads_notifier.dart';
import 'package:mira/shell/download/download_service_desktop.dart';
import 'package:mira/shell/download/download_service_mobile.dart';
import 'package:mira/shell/download/download_service_stub.dart';

/// Single source of truth for the downloads state.
///
/// Platform decision for [DownloadService] lives here. [DownloadsNotifier] also
/// persists the catalog to JSON on desktop (see [DownloadsNotifier]).
/// The [late] variable pattern is safe because the service callbacks are only ever
/// invoked after the notifier is fully constructed and assigned.
final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<MiraDownloadTask>>((ref) {
  
  if (kIsWeb) {
    return DownloadsNotifier(StubDownloadService());
  }

  late DownloadsNotifier notifier;

  if (Platform.isAndroid || Platform.isIOS) {
    final service = MobileDownloadService(
      onTasksReloaded: (tasks) => notifier.setTasks(tasks),
      // The Isolate Bridge remains intact so mobile progress bars work!
      onTaskUpdated: (id, updater) => notifier.updateTask(id, updater),
    );
    notifier = DownloadsNotifier(service);
  } else {
    final service = DesktopDownloadService(
      onTaskAdded: (task) => notifier.addTask(task),
      onTaskUpdated: (id, fn) => notifier.updateTask(id, fn),
    );
    notifier = DownloadsNotifier(service);
  }

  return notifier;
});