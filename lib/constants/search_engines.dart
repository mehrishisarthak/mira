class SearchEngines {
  // Keys for internal logic
  static const String google = 'google';
  static const String duckDuckGo = 'duckduckgo';
  static const String bing = 'bing';
  static const String brave = 'brave';

  // Map to Base URLs
  static const Map<String, String> urls = {
    google: 'https://www.google.com/search?q=',
    duckDuckGo: 'https://duckduckgo.com/?q=',
    bing: 'https://www.bing.com/search?q=',
    brave: 'https://search.brave.com/search?q=',
  };

  static String getSearchUrl(String engineKey) {
    return urls[engineKey] ?? urls[google]!;
  }
}