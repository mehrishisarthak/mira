import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/services/adblock_service.dart';
import 'package:mira/core/services/browser_engine_blueprints.dart';

final adBlockRulesProvider = FutureProvider<List<AdBlockRule>>((ref) {
  return AdBlockService.loadRules();
});
