import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` only in the extra engine started by [desktop_multi_window] for private browsing.
final privateStandaloneWindowProvider = Provider<bool>((ref) => false);
