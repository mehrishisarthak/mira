class SecurityState {
  final bool isLocationBlocked;
  final bool isCameraBlocked;
  final bool isDesktopMode;

  SecurityState({
    required this.isLocationBlocked,
    required this.isCameraBlocked,
    required this.isDesktopMode,
  });

  SecurityState copyWith({
    bool? isLocationBlocked,
    bool? isCameraBlocked,
    bool? isDesktopMode,
  }) {
    return SecurityState(
      isLocationBlocked: isLocationBlocked ?? this.isLocationBlocked,
      isCameraBlocked: isCameraBlocked ?? this.isCameraBlocked,
      isDesktopMode: isDesktopMode ?? this.isDesktopMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityState &&
          other.isLocationBlocked == isLocationBlocked &&
          other.isCameraBlocked == isCameraBlocked &&
          other.isDesktopMode == isDesktopMode);

  @override
  int get hashCode => Object.hash(isLocationBlocked, isCameraBlocked, isDesktopMode);
}
