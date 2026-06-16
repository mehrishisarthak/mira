import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';

class AdBlockService {
  static List<AdBlockRule>? _cache;

  static Future<List<AdBlockRule>> loadRules() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/adblock/content_blockers.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cache!;
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
