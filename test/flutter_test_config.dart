import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applied automatically to every test in this directory.
///
/// Normal tabs persist through the encrypted SecureTabStore (O-04). There is no
/// real Keystore in unit tests, so stub the flutter_secure_storage channel
/// (reads return null, writes accepted) so the fire-and-forget `saveTabs()`
/// triggered by tab notifiers stays silent instead of logging fallback errors.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );
  await testMain();
}
