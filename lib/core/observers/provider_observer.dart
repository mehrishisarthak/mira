import 'package:flutter_riverpod/flutter_riverpod.dart';
class MiraProviderObserver extends ProviderObserver {
  const MiraProviderObserver();
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    final name = provider.name ?? provider.runtimeType.toString();
    // ignore: avoid_print
    print('[MIRA] Provider error in $name — $error');
  }
}