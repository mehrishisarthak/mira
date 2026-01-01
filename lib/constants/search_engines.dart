class SearchEngines {
  // Keys for internal logic
  static const String google = 'google';
  static const String duckDuckGo = 'duckduckgo';
  static const String bing = 'bing';
  static const String brave = 'brave';
  static const String yahoo = 'yahoo';
  static const String ecosia = 'ecosia';

  // Map to Base URLs
  static const Map<String, String> urls = {
    google: 'https://www.google.com/search?q=',
    duckDuckGo: 'https://duckduckgo.com/?q=',
    bing: 'https://www.bing.com/search?q=',
    brave: 'https://search.brave.com/search?q=',
    yahoo: 'https://search.yahoo.com/search?p=',
    ecosia: 'https://www.ecosia.org/search?q=',
  };

  static String getSearchUrl(String engineKey) {
    return urls[engineKey] ?? urls[google]!;
  }

  // Helper to get pretty names for UI
  static String getName(String key) {
    switch (key) {
      case duckDuckGo: return 'DuckDuckGo';
      case bing: return 'Bing';
      case brave: return 'Brave Search';
      case yahoo: return 'Yahoo';
      case ecosia: return 'Ecosia';
      case google: default: return 'Google';
    }
  }
}