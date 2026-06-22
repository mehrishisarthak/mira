import 'package:flutter_test/flutter_test.dart';
import 'package:mira/core/config/hibernation_limits.dart';
import 'package:mira/core/notifiers/hibernation_notifier.dart';

/// Pure LRU behaviour of the hibernation set — no platform channels, no Isar.
/// Cap is platform-derived, so assertions key off maxAliveWebViewTabs().
void main() {
  test('evicts the least-recently-woken tab beyond the cap', () {
    final notifier = HibernationNotifier();
    final cap = maxAliveWebViewTabs();

    for (var i = 0; i <= cap; i++) {
      notifier.wakeTab('t$i'); // cap + 1 distinct tabs
    }

    expect(notifier.state, hasLength(cap));
    expect(notifier.state.contains('t0'), isFalse, reason: 'oldest evicted');
    expect(notifier.state.contains('t$cap'), isTrue, reason: 'newest kept');
  });

  test('re-waking a tab protects it from eviction (LRU recency)', () {
    final notifier = HibernationNotifier();
    final cap = maxAliveWebViewTabs();

    for (var i = 0; i < cap; i++) {
      notifier.wakeTab('t$i'); // fill exactly to cap: t0..t(cap-1)
    }
    notifier.wakeTab('t0'); // t0 becomes most-recent
    notifier.wakeTab('new'); // forces a single eviction

    expect(notifier.state, hasLength(cap));
    expect(notifier.state.contains('t0'), isTrue, reason: 're-woken survives');
    expect(notifier.state.contains('t1'), isFalse, reason: 'now-oldest evicted');
    expect(notifier.state.contains('new'), isTrue);
  });

  test('onTabsClosed drops ids no longer present', () {
    final notifier = HibernationNotifier();
    notifier.wakeTab('a');
    notifier.wakeTab('b');
    notifier.wakeTab('c');

    notifier.onTabsClosed({'a', 'c'}); // b closed

    expect(notifier.state, containsAll(<String>['a', 'c']));
    expect(notifier.state.contains('b'), isFalse);
  });
}
