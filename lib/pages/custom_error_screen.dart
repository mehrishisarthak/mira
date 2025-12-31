import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/theme_model.dart';

class CustomErrorScreen extends ConsumerWidget {
  final String error;
  final String url;
  final VoidCallback onRetry;

  const CustomErrorScreen({
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

    final errorInfo = _getErrorInfo(error);

    return SizedBox.expand(
      child: Container(
        color: appTheme.backgroundColor,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(errorInfo.icon, size: 64, color: errorInfo.color),
            const SizedBox(height: 24),
            Text(
              errorInfo.title,
              style: TextStyle(
                color: errorInfo.color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Target: $url",
              style: TextStyle(color: contentColor.withOpacity(0.5), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              errorInfo.description,
              style: TextStyle(color: contentColor.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: appTheme.primaryColor),
              label: Text("RETRY", style: TextStyle(color: appTheme.primaryColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: appTheme.primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            )
          ],
        ),
      ),
    );
  }

  _ErrorInfo _getErrorInfo(String error) {
    if (error.contains('net::ERR_INTERNET_DISCONNECTED')) {
      return _ErrorInfo(
        icon: Icons.wifi_off,
        color: Colors.orangeAccent,
        title: 'NO CONNECTION',
        description: 'Your device is not connected to the internet. Please check your network settings.',
      );
    }
    if (error.contains('net::ERR_CONNECTION_TIMED_OUT')) {
      return _ErrorInfo(
        icon: Icons.timer_off_outlined,
        color: Colors.blueAccent,
        title: 'TIMED OUT',
        description: 'The server at $url took too long to respond. It might be temporarily down.',
      );
    }
    if (error.contains('net::ERR_SSL_PROTOCOL_ERROR') || error.contains('net::ERR_CERT_COMMON_NAME_INVALID')) {
      return _ErrorInfo(
        icon: Icons.security_outlined,
        color: Colors.redAccent,
        title: 'SECURITY WARNING',
        description: 'The site\'s security certificate is invalid. This could be a misconfiguration or a malicious attempt to intercept your data.',
      );
    }
    if (error.startsWith('HTTP Error: 404')) {
      return _ErrorInfo(
        icon: Icons.fmd_bad_outlined,
        color: Colors.amber,
        title: 'NOT FOUND',
        description: 'The requested page could not be found on the server.',
      );
    }
    if (error.startsWith('HTTP Error: 5')) { // 5xx errors
      return _ErrorInfo(
        icon: Icons.dns_outlined,
        color: Colors.redAccent,
        title: 'SERVER ERROR',
        description: 'The server at $url encountered an internal error and could not complete your request.',
      );
    }
    
    return _ErrorInfo(
      icon: Icons.signal_wifi_bad,
      color: Colors.redAccent,
      title: 'CONNECTION FAILED',
      description: error,
    );
  }
}

class _ErrorInfo {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  _ErrorInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
