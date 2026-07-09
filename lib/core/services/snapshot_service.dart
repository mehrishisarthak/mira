import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

final snapshotServiceProvider = Provider<SnapshotService>((ref) {
  return SnapshotService(ref);
});

class SnapshotService {
  final Ref _ref;
  final Set<String> _pendingDeletions = {};
  
  SnapshotService(this._ref);

  Future<void> writeSnapshot(String tabId, Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final snapshotsDir = Directory('${dir.path}/snapshots');
      if (!await snapshotsDir.exists()) {
        await snapshotsDir.create(recursive: true);
      }

      final file = File('${snapshotsDir.path}/tab_$tabId.png');
      
      // If a deletion was requested while we were waiting for the directory
      if (_pendingDeletions.contains(tabId)) {
        _pendingDeletions.remove(tabId);
        return;
      }

      await file.writeAsBytes(bytes);

      // If a deletion was requested while we were writing
      if (_pendingDeletions.contains(tabId)) {
        if (await file.exists()) {
          await file.delete();
        }
        _pendingDeletions.remove(tabId);
        return;
      }

      // Update the cache provider to point to the file instead of bytes
      final currentCache = _ref.read(tabSnapshotCacheProvider);
      // Only update if the tab is still in the cache (hasn't been closed)
      if (currentCache.containsKey(tabId)) {
        _ref.read(tabSnapshotCacheProvider.notifier).update((state) {
          final newState = Map<String, TabSnapshotData>.from(state);
          newState[tabId] = TabSnapshotData(diskPath: file.path);
          return newState;
        });
      }
    } catch (e) {
      // Handle or log error
    }
  }

  Future<void> deleteSnapshot(String tabId) async {
    _pendingDeletions.add(tabId);
    
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/snapshots/tab_$tabId.png');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore
    } finally {
      _pendingDeletions.remove(tabId);
    }
  }

  static Future<void> clearStaleSnapshots() async {
    try {
      final dir = await getTemporaryDirectory();
      final snapshotsDir = Directory('${dir.path}/snapshots');
      if (await snapshotsDir.exists()) {
        await snapshotsDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore
    }
  }
}
