class SecurityState {
  final bool isLocationBlocked;
  final bool isCameraBlocked;
  final bool isDesktopMode;
  final bool isAdBlockEnabled;

  SecurityState({
    required this.isLocationBlocked,
    required this.isCameraBlocked,
    required this.isDesktopMode,
    this.isAdBlockEnabled = true,
  });

  SecurityState copyWith({
    bool? isLocationBlocked,
    bool? isCameraBlocked,
    bool? isDesktopMode,
    bool? isAdBlockEnabled,
  }) {
    return SecurityState(
      isLocationBlocked: isLocationBlocked ?? this.isLocationBlocked,
      isCameraBlocked: isCameraBlocked ?? this.isCameraBlocked,
      isDesktopMode: isDesktopMode ?? this.isDesktopMode,
      isAdBlockEnabled: isAdBlockEnabled ?? this.isAdBlockEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityState &&
          other.isLocationBlocked == isLocationBlocked &&
          other.isCameraBlocked == isCameraBlocked &&
          other.isDesktopMode == isDesktopMode &&
          other.isAdBlockEnabled == isAdBlockEnabled);

  @override
  int get hashCode =>
      Object.hash(isLocationBlocked, isCameraBlocked, isDesktopMode, isAdBlockEnabled);
}
