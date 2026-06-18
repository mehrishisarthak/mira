import 'package:flutter/material.dart';

/// App-wide keys for driving UI from non-widget code (e.g. browser stream
/// side-effects that have a [WidgetRef] but no [BuildContext]).
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
