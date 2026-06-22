import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mira/core/services/update_service.dart';

/// Serves a version manifest so [UpdateService.checkForUpdate] exercises the
/// real version-comparison logic without a network call.
http.Client _client({
  required String minimum,
  required String latest,
}) {
  return MockClient((_) async => http.Response(
        jsonEncode({
          'minimum_version': minimum,
          'latest_version': latest,
          'store_url': 'https://example.com/app',
        }),
        200,
      ));
}

void main() {
  test('pre-release latest is offered, not silently skipped', () async {
    // Regression for O-19: int.parse('0-beta') used to throw -> upToDate.
    final result = await UpdateService.checkForUpdate(
      '1.0.0',
      client: _client(minimum: '1.0.0', latest: '2.0.0-beta.1'),
    );
    expect(result.status, UpdateStatus.updateAvailable);
  });

  test('v-prefixed latest is compared by its numeric core', () async {
    final result = await UpdateService.checkForUpdate(
      '1.1.0',
      client: _client(minimum: '1.0.0', latest: 'v1.2.0'),
    );
    expect(result.status, UpdateStatus.updateAvailable);
  });

  test('build metadata on installed version still parses', () async {
    final result = await UpdateService.checkForUpdate(
      '1.4.0+42',
      client: _client(minimum: '2.0.0', latest: '2.0.0'),
    );
    expect(result.status, UpdateStatus.forceUpdate);
  });

  test('equal versions report up to date', () async {
    final result = await UpdateService.checkForUpdate(
      '2.0.0',
      client: _client(minimum: '1.0.0', latest: '2.0.0'),
    );
    expect(result.status, UpdateStatus.upToDate);
  });

  test('below minimum forces update', () async {
    final result = await UpdateService.checkForUpdate(
      '1.0.0',
      client: _client(minimum: '1.5.0', latest: '2.0.0'),
    );
    expect(result.status, UpdateStatus.forceUpdate);
  });
}
