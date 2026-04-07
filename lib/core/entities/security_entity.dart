class SecurityState {
  final bool isIncognito;
  final bool isLocationBlocked;
  final bool isCameraBlocked;
  final bool isDesktopMode;
  final bool isAdBlockEnabled;
  final bool isProxyEnabled;
  final String proxyUrl;
  /// When true, the iOS local gateway [HttpClient] accepts any server TLS certificate
  /// (needed for some corporate / intercepting HTTP proxies). Off by default.
  final bool proxyAllowInsecureCertificates;

  SecurityState({
    required this.isIncognito,
    required this.isLocationBlocked,
    required this.isCameraBlocked,
    required this.isDesktopMode,
    required this.isAdBlockEnabled,
    required this.isProxyEnabled,
    required this.proxyUrl,
    required this.proxyAllowInsecureCertificates,
  });

  SecurityState copyWith({
    bool? isIncognito,
    bool? isLocationBlocked,
    bool? isCameraBlocked,
    bool? isDesktopMode,
    bool? isAdBlockEnabled,
    bool? isProxyEnabled,
    String? proxyUrl,
    bool? proxyAllowInsecureCertificates,
  }) {
    return SecurityState(
      isIncognito: isIncognito ?? this.isIncognito,
      isLocationBlocked: isLocationBlocked ?? this.isLocationBlocked,
      isCameraBlocked: isCameraBlocked ?? this.isCameraBlocked,
      isDesktopMode: isDesktopMode ?? this.isDesktopMode,
      isAdBlockEnabled: isAdBlockEnabled ?? this.isAdBlockEnabled,
      isProxyEnabled: isProxyEnabled ?? this.isProxyEnabled,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      proxyAllowInsecureCertificates: proxyAllowInsecureCertificates ??
          this.proxyAllowInsecureCertificates,
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
          other.proxyUrl == proxyUrl &&
          other.proxyAllowInsecureCertificates == proxyAllowInsecureCertificates);

  @override
  int get hashCode => Object.hash(
        isIncognito,
        isLocationBlocked,
        isCameraBlocked,
        isDesktopMode,
        isAdBlockEnabled,
        isProxyEnabled,
        proxyUrl,
        proxyAllowInsecureCertificates,
      );
}
