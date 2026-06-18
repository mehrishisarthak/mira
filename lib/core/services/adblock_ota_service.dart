import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:mira/core/services/preferences_service.dart';

/// Client half of the weekly OTA tracker-list refresh.
///
/// Downloads land on disk and are picked up by [AdBlockService.loadRules] on the
/// NEXT launch — running webviews are never live-mutated.
class AdBlockOtaService {
  // Repo slug for the OTA release assets. If the GitHub repository is renamed
  // or moved (e.g. a rebrand), change this single line.
  static const _releaseBase =
      'https://github.com/mehrishisarthak/mira/releases/latest/download';
  static const _manifestUrl = '$_releaseBase/manifest.json';
  static const _rulesUrl = '$_releaseBase/content_blockers.json';

  static const Duration _interval = Duration(days: 7);

  /// Single source of truth for the on-disk OTA rules file, shared with the
  /// loader. Returns the absolute path to `<appSupport>/adblock/content_blockers.json`.
  static Future<String> rulesFilePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'adblock', 'content_blockers.json');
  }

  /// Background check, throttled to once per [_interval]. Never throws.
  ///
  /// [httpClient] is injected only by tests; production uses a default client.
  static Future<void> maybeRefresh(PreferencesService prefs,
      {http.Client? httpClient}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - prefs.getAdBlockOtaLastCheck() < _interval.inMilliseconds) return;
    // Record the attempt regardless of outcome so a persistent failure does not
    // re-hit the network every launch.
    await prefs.setAdBlockOtaLastCheck(now);

    final client = httpClient ?? http.Client();
    try {
      final manifestRes = await client.get(Uri.parse(_manifestUrl));
      if (manifestRes.statusCode != 200) return;
      final manifest = jsonDecode(manifestRes.body) as Map<String, dynamic>;
      final remoteSha = (manifest['sha256'] as String).toLowerCase();

      if (remoteSha == prefs.getAdBlockOtaSha()) return; // already applied

      final rulesRes = await client.get(Uri.parse(_rulesUrl));
      if (rulesRes.statusCode != 200) return;
      final bytes = rulesRes.bodyBytes;

      final actualSha = sha256.convert(bytes).toString();
      if (actualSha != remoteSha) return; // integrity check failed

      final filePath = await rulesFilePath();
      final file = File(filePath);
      await file.parent.create(recursive: true);
      // Atomic write: temp file in the same dir, then rename.
      final tmp = File('$filePath.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(filePath);

      await prefs.setAdBlockOtaSha(remoteSha);
    } catch (e) {
      // Network/parse/verify failure: keep last good list.
      debugPrint('MIRA: AdBlock OTA refresh failed: $e');
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
