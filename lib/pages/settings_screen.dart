import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/search_engine.dart';
import '../constants/search_engines.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEngine = ref.watch(searchEngineProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            "Search Engine",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // List of Search Engines
          // We loop through the keys in your Constants file
          ...SearchEngines.urls.keys.map((engineKey) {
            return RadioListTile<String>(
              title: Text(
                engineKey.toUpperCase(), // "GOOGLE", "DUCKDUCKGO"
                style: const TextStyle(color: Colors.white70),
              ),
              value: engineKey,
              // ignore: deprecated_member_use
              groupValue: currentEngine,
              activeColor: Colors.greenAccent,
              contentPadding: EdgeInsets.zero,
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  // Update the provider
                  ref.read(searchEngineProvider.notifier).setEngine(value);
                  // Optional: Close settings immediately after selection
                  // Navigator.pop(context); 
                }
              },
            );
          }),

          const Divider(color: Colors.white24),

          // Placeholder for future features
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text("Clear Data", style: TextStyle(color: Colors.redAccent)),
            onTap: () {
               // We will add the logic to clear cookies later
               Navigator.pop(context); 
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Data Cleared (Simulation)")),
               );
            },
          ),
        ],
      ),
    );
  }
}