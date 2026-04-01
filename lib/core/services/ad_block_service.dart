abstract class AdBlockService {
  /// List of domains to block at the network level.
  List<String> get blockedDomains;

  /// Raw JavaScript and CSS rules to inject into the page.
  /// Implementations will convert these into platform-specific objects
  /// like UserScript or ContentBlocker.
  List<AdBlockRule> get adBlockRules;

  String get shieldScript;
}

enum AdBlockRuleType { block, cssHiding, scriptMock }

class AdBlockRule {
  final String urlFilter;
  final AdBlockRuleType type;
  final List<String>? resourceTypes;

  const AdBlockRule({
    required this.urlFilter,
    required this.type,
    this.resourceTypes,
  });
}
