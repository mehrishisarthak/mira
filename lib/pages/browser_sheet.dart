import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/theme_model.dart';
import '../constants/search_engines.dart';

class BrowserSheet extends ConsumerWidget {
  const BrowserSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEngine = ref.watch(searchEngineProvider);
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: appTheme.surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: contentColor.withAlpha(51),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            "Search Engine",
            style: TextStyle(
              color: contentColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          ...SearchEngines.urls.keys.map((engineKey) {
            return RadioListTile<String>(
              title: Text(
                engineKey.toUpperCase(),
                style: TextStyle(color: contentColor.withAlpha(179)),
              ),
              value: engineKey,
              groupValue: currentEngine,
              activeColor: appTheme.accentColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                if (value != null) {
                  ref.read(searchEngineProvider.notifier).setEngine(value);
                }
              },
            );
          }),
        ],
      ),
    );
  }
}