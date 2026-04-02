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
  /// Compares major.minor.patch segments numerically.
  static bool _isBelow(String version, String minimum) {
    try {
      final v = version.split('.').map(int.parse).toList();
      final m = minimum.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final vSeg = i < v.length ? v[i] : 0;
        final mSeg = i < m.length ? m[i] : 0;

        if (vSeg < mSeg) return true;
        if (vSeg > mSeg) return false;
      }
      return false; // equal
    } catch (e) {
      return false; // parse error — don't block
    }
  }
}
