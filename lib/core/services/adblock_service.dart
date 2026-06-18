import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:mira/core/services/adblock_ota_service.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';

class AdBlockService {
  static List<AdBlockRule>? _cache;

  static Future<List<AdBlockRule>> loadRules() async {
    if (_cache != null) return _cache!;
    // Prefer the OTA file on disk; fall back to the bundled asset if it is
    // absent, unreadable, or fails to parse (asset must always work offline).
    final fromDisk = await _tryLoadFromDisk();
    if (fromDisk != null) {
      _cache = fromDisk;
      return _cache!;
    }
    final raw = await rootBundle.loadString('assets/adblock/content_blockers.json');
    _cache = _parse(raw);
    return _cache!;
  }

  static Future<List<AdBlockRule>?> _tryLoadFromDisk() async {
    try {
      final file = File(await AdBlockOtaService.rulesFilePath());
      if (!await file.exists()) return null;
      return _parse(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  static List<AdBlockRule> _parse(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Synchronous read of the pre-warmed cache.
  /// Returns the cached rules if main.dart's pre-warm has run, otherwise empty.
  /// Use this in Provider bodies where async resolution would cause a race.
  static List<AdBlockRule> loadRulesSync() => _cache ?? const <AdBlockRule>[];

  static AdBlockRule _fromJson(Map<String, dynamic> json) {
    final trigger = json['trigger'] as Map<String, dynamic>;
    final action = json['action'] as Map<String, dynamic>;
    return AdBlockRule(
      urlFilter: trigger['urlFilter'] as String,
      isBlock: (action['type'] as String) == 'BLOCK',
    );
  }
}
