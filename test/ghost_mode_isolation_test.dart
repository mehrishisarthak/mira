import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/core/services/preferences_service.dart';
import 'package:qyx/core/services/snapshot_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies that Ghost Mode never persists tab snapshots to disk.
///
/// Note: this file deliberately does NOT re-test that Ghost Mode suppresses
/// history recording — that's already covered by
/// test/browser_history_recording_test.dart ("loadStop in ghost mode records
/// nothing"), which exercises `handleEnginePageEvent` directly. Duplicating
/// that here would just be two tests protecting the same line of code.
///
/// [GhostTabsNotifier] takes no [SnapshotService] dependency at all (compare
/// its constructor to [TabsNotifier], which does) — so ghost tabs have no
/// code path to disk-persisted snapshots by construction. This test locks
/// that invariant in: if a future refactor ever wires a SnapshotService into
/// GhostTabsNotifier without gating writes on ghost mode, this test starts
/// failing.
class _RecordingSnapshotService extends SnapshotService {
  final List<String> writes = [];
  final List<String> deletes = [];

  _RecordingSnapshotService(Ref ref) : super(ref);

  @override
  Future<void> writeSnapshot(String tabId, Uint8List bytes) async {
    writes.add(tabId);
  }

  @override
  Future<void> deleteSnapshot(String tabId) async {
    deletes.add(tabId);
  }
}

Future<(ProviderContainer, _RecordingSnapshotService)> _makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  late _RecordingSnapshotService snapshotService;
  final container = ProviderContainer(
    overrides: [
      preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
      snapshotServiceProvider.overrideWith((ref) {
        snapshotService = _RecordingSnapshotService(ref);
        return snapshotService;
      }),
    ],
  );
  addTearDown(container.dispose);

  // Force tabsProvider to build now so the override above is realized before
  // we hand back the recording service.
  container.read(tabsProvider);
  return (container, snapshotService);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sanity check: closing a normal tab does reach SnapshotService.deleteSnapshot',
      () async {
    final (container, snapshotService) = await _makeContainer();
    final notifier = container.read(tabsProvider.notifier);

    notifier.addTab(url: 'https://example.com');
    final closedId = container.read(tabsProvider).tabOrder.first;
    notifier.closeTab(closedId);

    // Proves the fake is actually wired into the live TabsNotifier path —
    // without this, an empty `deletes` list in the ghost test below would be
    // a false negative (nothing ever reaching the service at all) rather
    // than a true positive (ghost tabs specifically never reaching it).
    expect(snapshotService.deletes, contains(closedId));
  });

  test(
      'ghost tabs never write or delete snapshots on disk through add/switch/close/nuke',
      () async {
    final (container, snapshotService) = await _makeContainer();
    final ghostNotifier = container.read(ghostTabsProvider.notifier);

    ghostNotifier.addTab(url: 'https://a.example.com');
    ghostNotifier.addTab(url: 'https://b.example.com');
    ghostNotifier.addTab(url: 'https://c.example.com');
    ghostNotifier.switchTab(0);
    ghostNotifier.switchTabById(container.read(ghostTabsProvider).tabOrder.last);

    final ghostTabId = container.read(ghostTabsProvider).tabOrder.first;
    ghostNotifier.closeTab(ghostTabId);
    ghostNotifier.nuke();

    expect(snapshotService.writes, isEmpty,
        reason: 'Ghost Mode must never write a tab snapshot to disk.');
    expect(snapshotService.deletes, isEmpty,
        reason:
            'Ghost tabs have no SnapshotService reference, so no delete call should ever occur for them either.');
  });
}
