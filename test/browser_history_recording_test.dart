import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';
import 'package:mira/core/services/database_providers.dart';
import 'package:mira/core/services/isar_database_repository.dart';
import 'package:mira/core/services/isar_schemas.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:mira/pages/browser/browser_side_effects.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures history writes without touching Isar. [HistoryNotifier] only calls
/// init(), watchAll() and upsertByUrl(), so those are the only overrides needed.
class _RecordingHistoryRepository extends IsarHistoryRepository {
  final List<({String url, String title})> upserts = [];

  @override
  Future<void> init() async {}

  @override
  Stream<List<HistoryItemSchema>> watchAll() =>
      Stream<List<HistoryItemSchema>>.empty();

  @override
  Future<void> upsertByUrl(
    String url,
    String title, {
    Duration dedupeWindow = const Duration(minutes: 30),
  }) async {
    upserts.add((url: url, title: title));
  }
}

/// Hands a real provider [Ref] to the test so [handleEnginePageEvent] can be
/// driven exactly as the live subscription would drive it.
final _refProbe = Provider<Ref>((ref) => ref);

Future<ProviderContainer> _makeContainer(
  _RecordingHistoryRepository repo,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      preferencesServiceProvider.overrideWithValue(PreferencesService(prefs)),
      historyRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadStop records history even with no title change', () async {
    final repo = _RecordingHistoryRepository();
    final container = await _makeContainer(repo);
    final ref = container.read(_refProbe);

    handleEnginePageEvent(
      ref,
      const BrowserPageEvent(
        type: BrowserPageEventType.loadStop,
        url: 'https://example.com',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repo.upserts.map((e) => e.url), contains('https://example.com'));
  });

  test('loadStop in ghost mode records nothing', () async {
    final repo = _RecordingHistoryRepository();
    final container = await _makeContainer(repo);
    container.read(isGhostModeProvider.notifier).state = true;
    final ref = container.read(_refProbe);

    handleEnginePageEvent(
      ref,
      const BrowserPageEvent(
        type: BrowserPageEventType.loadStop,
        url: 'https://example.com',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repo.upserts, isEmpty);
  });

  test('loadStop with a null url records nothing', () async {
    final repo = _RecordingHistoryRepository();
    final container = await _makeContainer(repo);
    final ref = container.read(_refProbe);

    handleEnginePageEvent(
      ref,
      const BrowserPageEvent(type: BrowserPageEventType.loadStop),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repo.upserts, isEmpty);
  });

  test('titleChanged keys history off the event url, not the active tab url',
      () async {
    final repo = _RecordingHistoryRepository();
    final container = await _makeContainer(repo);
    // The active tab points somewhere else than the title event's page.
    container.read(tabsProvider.notifier).updateUrl('https://active-tab.com');
    final ref = container.read(_refProbe);

    handleEnginePageEvent(
      ref,
      const BrowserPageEvent(
        type: BrowserPageEventType.titleChanged,
        title: 'Event Title',
        url: 'https://event-page.com',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(repo.upserts, hasLength(1));
    expect(repo.upserts.single.url, 'https://event-page.com');
    expect(repo.upserts.single.title, 'Event Title');
  });
}
