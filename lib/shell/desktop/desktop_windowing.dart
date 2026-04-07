import 'desktop_windowing_stub.dart'
    if (dart.library.io) 'desktop_windowing_io.dart' as impl;

Future<void> desktopWindowManagerInit() => impl.desktopWindowManagerInit();

Future<void> desktopSetWindowTitle(String title) =>
    impl.desktopSetWindowTitle(title);
