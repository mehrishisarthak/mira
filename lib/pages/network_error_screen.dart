import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/theme_model.dart';

class ErrorScreen extends ConsumerWidget {
  final String error;
  final String url;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.url,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;

    return Container(
      color: appTheme.backgroundColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_wifi_bad, size: 64, color: Colors.redAccent),
          const SizedBox(height: 24),
          const Text(
            "CONNECTION FAILED",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Target: $url",
            style: TextStyle(color: contentColor.withOpacity(0.5), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            error,
            style: TextStyle(color: contentColor.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: appTheme.primaryColor),
            label: Text("RE-ESTABLISH", style: TextStyle(color: appTheme.primaryColor)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: appTheme.primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          )
        ],
      ),
    );
  }
}