// Dart conditional exports can only check for library availability,
// not runtime values like Platform.isAndroid.
//
// - Web: dart:io is unavailable → StubDownloadService
// - All native targets (Android, iOS, Windows, macOS, Linux):
//   dart:io is available → the io-capable file is exported.
//
// The mobile vs desktop split (MobileDownloadService vs
// DesktopDownloadService) is done at runtime with Platform checks
// inside the provider factory — see lib/core/notifiers/.
export 'download_service_stub.dart'
    if (dart.library.io) 'download_service_desktop.dart';
