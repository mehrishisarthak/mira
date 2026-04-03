class SecurityState {
  final bool isIncognito;
  final bool isLocationBlocked;
  final bool isCameraBlocked;
  final bool isDesktopMode;
  final bool isAdBlockEnabled;
  final bool isProxyEnabled;
  final String proxyUrl;

  SecurityState({
    required this.isIncognito,
    required this.isLocationBlocked,
    required this.isCameraBlocked,
    required this.isDesktopMode,
    required this.isAdBlockEnabled,
    required this.isProxyEnabled,
    required this.proxyUrl,
  });

  SecurityState copyWith({
    bool? isIncognito,
    bool? isLocationBlocked,
    bool? isCameraBlocked,
    bool? isDesktopMode,
    bool? isAdBlockEnabled,
    bool? isProxyEnabled,
    String? proxyUrl,
  }) {
    return SecurityState(
      isIncognito: isIncognito ?? this.isIncognito,
      isLocationBlocked: isLocationBlocked ?? this.isLocationBlocked,
      isCameraBlocked: isCameraBlocked ?? this.isCameraBlocked,
      isDesktopMode: isDesktopMode ?? this.isDesktopMode,
      isAdBlockEnabled: isAdBlockEnabled ?? this.isAdBlockEnabled,
      isProxyEnabled: isProxyEnabled ?? this.isProxyEnabled,
      proxyUrl: proxyUrl ?? this.proxyUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityState &&
          other.isIncognito == isIncognito &&
          other.isLocationBlocked == isLocationBlocked &&
          other.isCameraBlocked == isCameraBlocked &&
          other.isDesktopMode == isDesktopMode &&
          other.isAdBlockEnabled == isAdBlockEnabled &&
          other.isProxyEnabled == isProxyEnabled &&
          other.proxyUrl == proxyUrl);

  @override
  int get hashCode => Object.hash(
        isIncognito,
        isLocationBlocked,
        isCameraBlocked,
        isDesktopMode,
        isAdBlockEnabled,
        isProxyEnabled,
        proxyUrl,
      );
}
