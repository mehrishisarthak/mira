import 'package:flutter_test/flutter_test.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// reorderTab index math + active-tab tracking. GhostTabsNotifier starts empty
/// (cleanest fixture); TabsNotifier shares the identical algorithm and is
/// exercised once through its persisted path.
void main() {
  GhostTabsNotifier ghostWith(List<String> urls) {
    final n = GhostTabsNotifier();
    for (final u in urls) {
      n.addTab(url: u);
    }
    return n;
  }

  List<String> urls(GhostTabsNotifier n) =>
      n.state.tabOrder.map((id) => n.state.tabs[id]!.url).toList();
  String activeUrl(GhostTabsNotifier n) =>
      n.state.tabs[n.state.tabOrder[n.state.activeIndex]]!.url;

  test('forward move keeps a non-moved active tab tracked', () {
    final n = ghostWith(['a', 'b', 'c', 'd']);
    n.switchTab(2); // active = c
    n.reorderTab(0, 3); // move a toward the end
    expect(urls(n), ['b', 'c', 'a', 'd']);
    expect(activeUrl(n), 'c');
  });

  test('active follows the moved tab', () {
    final n = ghostWith(['a', 'b', 'c', 'd']);
    n.switchTab(0); // active = a
    n.reorderTab(0, 2);
    expect(urls(n), ['b', 'a', 'c', 'd']);
    expect(activeUrl(n), 'a');
  });

  test('backward move shifts a displaced active index', () {
    final n = ghostWith(['a', 'b', 'c', 'd']);
    n.switchTab(0); // active = a (index 0)
    n.reorderTab(3, 0); // move d to front
    expect(urls(n), ['d', 'a', 'b', 'c']);
    expect(activeUrl(n), 'a');
  });

  test('out-of-range reorder is a no-op', () {
    final n = ghostWith(['a', 'b']);
    n.reorderTab(0, 5);
    n.reorderTab(-1, 1);
    expect(urls(n), ['a', 'b']);
  });

  test('TabsNotifier reorder moves the tab on its persisted path', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final n = TabsNotifier(PreferencesService(prefs));
    n.addTab(url: 'a'); // [blank, a]
    n.addTab(url: 'b'); // [blank, a, b], active = 2
    n.reorderTab(2, 0); // move b to front
    expect(n.state.tabs[n.state.tabOrder.first]!.url, 'b');
    expect(n.state.tabs[n.state.tabOrder[n.state.activeIndex]]!.url, 'b');
  });
}




