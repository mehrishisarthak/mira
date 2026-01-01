import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/tab_model.dart';
import 'package:mira/model/theme_model.dart';
class BrandingScreen extends ConsumerWidget {
  const BrandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGhost = ref.watch(isGhostModeProvider);

    return isGhost 
        ? const _GhostLandingPage() 
        : const _NormalSpeedDial();
  }
}

// --- 1. GHOST MODE LANDING SCREEN ---
class _GhostLandingPage extends StatelessWidget {
  const _GhostLandingPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000), // Pure Black for Ghost
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(Icons.privacy_tip, size: 80, color: Colors.redAccent.withAlpha(204)),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              "GHOST PROTOCOL ACTIVE",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // PROTECTED LIST
          const Text(
            "SYSTEMS OFFLINE (NOT SAVED):",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildGhostItem(Icons.history, "Browsing History"),
          _buildGhostItem(Icons.cookie, "Cookies & Site Data"),
          _buildGhostItem(Icons.cached, "Form Data & Cache"),

          const SizedBox(height: 32),

          // VISIBLE LIST
          const Text(
            "VISIBLE TO OTHERS:",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildGhostItem(Icons.wifi, "Network Provider / ISP", isWarning: true),
          _buildGhostItem(Icons.download, "Files Saved to Device", isWarning: true),
          _buildGhostItem(Icons.admin_panel_settings, "Websites you visit", isWarning: true),
        ],
      ),
    );
  }

  Widget _buildGhostItem(IconData icon, String text, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon, 
            size: 18, 
            color: isWarning ? Colors.white38 : Colors.redAccent // Red for Safe, Grey for Warning
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isWarning ? Colors.white38 : Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. NORMAL SPEED DIAL ---
class _NormalSpeedDial extends ConsumerWidget {
  const _NormalSpeedDial();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    
    final textColor = appTheme.mode == ThemeMode.light ? Colors.black87 : Colors.white;
    final cardColor = appTheme.primaryColor.withAlpha(26);
    final borderColor = appTheme.primaryColor.withAlpha(77);

    return Container(
      color: appTheme.backgroundColor,
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SPEED DIAL GRID
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _SpeedDialItem(
                    label: "YouTube", 
                    icon: Icons.play_arrow, 
                    url: "https://m.youtube.com",
                    color: textColor, 
                    bgColor: cardColor,
                    borderColor: borderColor,
                    ref: ref
                  ),
                  _SpeedDialItem(
                    label: "Reddit", 
                    icon: Icons.reddit, 
                    url: "https://www.reddit.com",
                    color: textColor, 
                    bgColor: cardColor,
                    borderColor: borderColor,
                    ref: ref
                  ),
                  _SpeedDialItem(
                    label: "GitHub", 
                    icon: Icons.code, 
                    url: "https://github.com",
                    color: textColor, 
                    bgColor: cardColor,
                    borderColor: borderColor,
                    ref: ref
                  ),
                  _SpeedDialItem(
                    label: "Wiki", 
                    icon: Icons.language, 
                    url: "https://en.wikipedia.org",
                    color: textColor, 
                    bgColor: cardColor,
                    borderColor: borderColor,
                    ref: ref
                  ),
                  _SpeedDialItem(
                    label: "DuckDuckGo", 
                    icon: Icons.search, 
                    url: "https://duckduckgo.com",
                    color: textColor, 
                    bgColor: cardColor,
                    borderColor: borderColor,
                    ref: ref
                  ),
                  _SpeedDialItem(
                    label: "HackerNews", 
                    icon: Icons.newspaper, 
                    url: "https://news.ycombinator.com",
                    color: textColor, 
                    bgColor: cardColor,
                    borderColor: borderColor,
                    ref: ref
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedDialItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String url;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final WidgetRef ref;

  const _SpeedDialItem({
    required this.label,
    required this.icon,
    required this.url,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Since Speed Dial only appears in Normal Mode, we only update Normal Tabs
        ref.read(tabsProvider.notifier).updateUrl(url);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color.withAlpha(204),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}