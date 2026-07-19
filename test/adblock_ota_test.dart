import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qyx/core/services/adblock_ota_service.dart';
import 'package:qyx/core/services/adblock_service.dart';
import 'package:qyx/core/services/preferences_service.dart';

/// End-to-end exercise of the OTA client, serving the REAL bundled blocklist
/// through a MockClient as if it were a fresh GitHub Release.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<int> rulesBytes;
  late String rulesSha;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mira_ota_test');

    // Redirect getApplicationSupportDirectory() to the temp dir.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );

    SharedPreferences.setMockInitialValues({});

    // Serve the actual shipped artifact as the "remote" payload.
    rulesBytes =
        await File('assets/adblock/content_blockers.json').readAsBytes();
    rulesSha = sha256.convert(rulesBytes).toString();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// A client that advertises [manifestSha] in its manifest and serves the real
  /// rules bytes for the content_blockers request.
  MockClient client(String manifestSha) {
    final manifest = jsonEncode({
      'schemaVersion': 1,
      'generatedAt': '2026-06-18T00:00:00Z',
      'sha256': manifestSha,
      'ruleCount': 1,
    });
    return MockClient((req) async {
      if (req.url.path.endsWith('manifest.json')) {
        return http.Response(manifest, 200);
      }
      if (req.url.path.endsWith('content_blockers.json')) {
        return http.Response.bytes(rulesBytes, 200);
      }
      return http.Response('not found', 404);
    });
  }

  test('downloads, sha256-verifies, writes to disk, and loadRules picks it up',
      () async {
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    await AdBlockOtaService.maybeRefresh(prefs, httpClient: client(rulesSha));

    final otaFile = File(await AdBlockOtaService.rulesFilePath());
    expect(await otaFile.exists(), isTrue, reason: 'OTA file should be written');
    expect(await otaFile.readAsBytes(), rulesBytes,
        reason: 'written bytes must equal downloaded bytes');
    expect(prefs.getAdBlockOtaSha(), rulesSha,
        reason: 'applied sha should be persisted');

    final rules = await AdBlockService.loadRules();
    expect(rules, isNotEmpty,
        reason: 'loader should read the OTA file from disk');
  });

  test('rejects a payload whose sha256 does not match the manifest', () async {
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    await AdBlockOtaService.maybeRefresh(prefs, httpClient: client('deadbeef'));

    final otaFile = File(await AdBlockOtaService.rulesFilePath());
    expect(await otaFile.exists(), isFalse,
        reason: 'integrity failure must not write a file');
    expect(prefs.getAdBlockOtaSha(), isNull,
        reason: 'integrity failure must not record a sha');
  });
}
