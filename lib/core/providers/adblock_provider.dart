import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/core/services/adblock_service.dart';
import 'package:qyx/core/services/browser_engine_blueprints.dart';

final adBlockRulesProvider = FutureProvider<List<AdBlockRule>>((ref) {
  return AdBlockService.loadRules();
});
