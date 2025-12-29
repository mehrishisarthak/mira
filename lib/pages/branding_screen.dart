import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/theme_model.dart';

class BrandingScreen extends ConsumerWidget {
  const BrandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;

    return Container(
      width: double.infinity,
      color: appTheme.backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.remove_red_eye_outlined,
            size: 120,
            color: contentColor.withAlpha(13),
          ),
          
          const SizedBox(height: 20),
          
          Text(
            "M I R A", 
            style: TextStyle(
              color: contentColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8.0,
            ),
          ),
          
          const SizedBox(height: 10),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: appTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                "NO TRACKERS ACTIVE",
                style: TextStyle(
                  color: appTheme.primaryColor.withAlpha(179),
                  fontSize: 12,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}