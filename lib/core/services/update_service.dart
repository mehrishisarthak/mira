import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateStatus {
  upToDate,
  updateAvailable,
  forceUpdate,
  checkFailed,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final String latestVersion;
  final String storeUrl;

  const UpdateCheckResult({
    required this.status,
    required this.latestVersion,
    required this.storeUrl,
  });
}

class UpdateService {
  static const String _updateUrl = 'https://mehrishisarthak.github.io/mira-updates/version.json';

  /// Convenience method to check for updates using the installed version.
  static Future<UpdateCheckResult> autoCheck({http.Client? client}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      return await checkForUpdate(info.version, client: client);
    } catch (e) {
      debugPrint('[MIRA] UpdateService: autoCheck failed -> $e');
      return const UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        latestVersion: '',
        storeUrl: '',
      );
    }
  }

  /// Checks for updates against the backend.
  /// [installedVersion] should be in format 'major.minor.patch'
  static Future<UpdateCheckResult> checkForUpdate(String installedVersion, {http.Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient
          .get(Uri.parse(_updateUrl))
          .timeout(const Duration(seconds: 5));
      
      if (client == null) httpClient.close(); // Only close if we created it

      if (response.statusCode != 200) {
        debugPrint('[MIRA] UpdateService: non-200 response ${response.statusCode}');
        return const UpdateCheckResult(
          status: UpdateStatus.checkFailed,
          latestVersion: '',
          storeUrl: '',
        );
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final minimumVersion = data['minimum_version'] as String;
      final latestVersion = data['latest_version'] as String;
      final storeUrl = data['store_url'] as String? ?? '';

      if (_isBelow(installedVersion, minimumVersion)) {
        return UpdateCheckResult(
          status: UpdateStatus.forceUpdate,
          latestVersion: latestVersion,
          storeUrl: storeUrl,
        );
      }

      if (_isBelow(installedVersion, latestVersion)) {
        return UpdateCheckResult(
          status: UpdateStatus.updateAvailable,
          latestVersion: latestVersion,
          storeUrl: storeUrl,
        );
      }

      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        latestVersion: latestVersion,
        storeUrl: storeUrl,
      );
    } catch (e) {
      debugPrint('[MIRA] UpdateService: check failed -> $e');
      return const UpdateCheckResult(
        status: UpdateStatus.checkFailed,
        latestVersion: '',
        storeUrl: '',
      );
    }
  }

  /// Returns true if [version] is strictly below [minimum].
  /// Compares the numeric major.minor.patch core; tolerant of a leading `v`
  /// and of pre-release/build suffixes (`2.0.0-beta.1`, `1.4.0+42`).
  static bool _isBelow(String version, String minimum) {
    final v = _parseCore(version);
    final m = _parseCore(minimum);

    for (int i = 0; i < 3; i++) {
      if (v[i] < m[i]) return true;
      if (v[i] > m[i]) return false;
    }
    return false; // equal
  }

  /// Parses the numeric major.minor.patch core of a semver-ish string into a
  /// 3-element list, never throwing. Strips a leading `v`/`V` and ignores any
  /// non-numeric suffix on a segment (`0-beta` → 0); missing segments are 0.
  static List<int> _parseCore(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final parts = s.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      final match = RegExp(r'^\d+').firstMatch(parts[i]);
      return match == null ? 0 : int.parse(match.group(0)!);
    });
  }
}
