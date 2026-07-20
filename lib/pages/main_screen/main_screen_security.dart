import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/constants/app_fonts.dart';

import 'package:qyx/core/entities/theme_entity.dart';
import 'package:qyx/core/notifiers/ghost_notifier.dart';
import 'package:qyx/core/notifiers/security_notifier.dart';
import 'package:qyx/core/notifiers/tab_notifier.dart';
import 'package:qyx/core/notifiers/theme_notifier.dart';
import 'package:qyx/core/providers/adblock_provider.dart';
import 'package:qyx/pages/browser_chrome_providers.dart';
import 'package:qyx/core/services/browser_engine_blueprints.dart';
import 'package:qyx/core/services/database_providers.dart';

// ── Security / permissions panel ──────────────────────────────────────────────

void showSecurityDialogForUrl(
  BuildContext context,
  String activeUrl,
  Color securityColor,
  Color contentColor,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SecurityPanel(
      activeUrl: activeUrl,
      securityColor: securityColor,
    ),
  );
}

class _SecurityPanel extends ConsumerWidget {
  final String activeUrl;
  final Color securityColor;

  const _SecurityPanel({
    required this.activeUrl,
    required this.securityColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final security = ref.watch(securityProvider);
    final isLight = theme.mode == ThemeMode.light;
    final surface = isLight ? Colors.white : const Color(0xFF1E1E1E);
    final textColor = isLight ? kMiraInkPrimary : Colors.white;
    final isSecure = activeUrl.startsWith('https://');
    final bottom = MediaQuery.of(context).padding.bottom;

    Uri? parsed;
    try { parsed = Uri.parse(activeUrl); } catch (_) {}
    final domain = parsed?.host ?? activeUrl;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (activeUrl.isNotEmpty) ...[
            const SizedBox(height: 20),

            // Domain + connection status
            Row(
              children: [
                Icon(
                  isSecure ? Icons.lock : Icons.lock_open,
                  color: securityColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain,
                        style: jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSecure
                            ? 'Connection is encrypted'
                            : 'Connection is not secure',
                        style: TextStyle(
                          fontSize: 12,
                          color: securityColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(height: 1, color: textColor.withValues(alpha: 0.08)),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 12),

          // Section label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'PERMISSIONS',
              style: jetBrainsMono(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.35),
                letterSpacing: 2.5,
              ),
            ),
          ),

          // Location toggle
          _PermissionRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            sublabel: security.isLocationBlocked ? 'Blocked' : 'Allowed',
            isBlocked: security.isLocationBlocked,
            textColor: textColor,
            onToggle: (val) {
              // Applying to every tab's engine (not just the active one) is
              // handled centrally by mainscreen.dart's securityProvider
              // listener, via applySecuritySettingsToAllTabs — this avoids a
              // background tab retaining a stale permission grant.
              ref.read(securityProvider.notifier).toggleLocation(!val);
            },
          ),

          // Camera & Mic toggle
          _PermissionRow(
            icon: Icons.mic_none,
            label: 'Camera & Mic',
            sublabel: security.isCameraBlocked ? 'Blocked' : 'Allowed',
            isBlocked: security.isCameraBlocked,
            textColor: textColor,
            onToggle: (val) {
              ref.read(securityProvider.notifier).toggleCamera(!val);
            },
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: textColor.withValues(alpha: 0.08)),
          const SizedBox(height: 8),

          // Desktop mode row
          _PermissionRow(
            icon: Icons.desktop_windows_outlined,
            label: 'Desktop Mode',
            sublabel: security.isDesktopMode ? 'On' : 'Off',
            isBlocked: false,
            isSwitch: true,
            switchValue: security.isDesktopMode,
            textColor: textColor,
            accentColor: theme.primaryColor,
            onToggle: (val) {
              ref.read(securityProvider.notifier).toggleDesktop(val);
            },
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: textColor.withValues(alpha: 0.08)),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'PRIVACY',
              style: jetBrainsMono(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.35),
                letterSpacing: 2.5,
              ),
            ),
          ),

          _PermissionRow(
            icon: Icons.shield_outlined,
            label: 'Ad & Tracker Block',
            sublabel: security.isAdBlockEnabled ? 'Active' : 'Off',
            isBlocked: false,
            isSwitch: true,
            switchValue: security.isAdBlockEnabled,
            textColor: textColor,
            accentColor: theme.primaryColor,
            onToggle: (val) {
              // toggleAdBlock updates securityProvider state.
              // mainscreen.dart's listener picks up the change and calls
              // _applyAdBlockToAllTabs — no direct engine call needed here.
              ref.read(securityProvider.notifier).toggleAdBlock(val);
            },
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isBlocked;
  final bool isSwitch;
  final bool switchValue;
  final Color textColor;
  final Color? accentColor;
  final void Function(bool) onToggle;

  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isBlocked,
    required this.textColor,
    required this.onToggle,
    this.isSwitch = false,
    this.switchValue = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = isSwitch
        ? (switchValue ? (accentColor ?? Colors.greenAccent) : textColor.withValues(alpha: 0.3))
        : (isBlocked ? Colors.greenAccent : Colors.orangeAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor.withValues(alpha: 0.5)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (isSwitch)
            Switch(
              value: switchValue,
              onChanged: onToggle,
              activeThumbColor: accentColor ?? Colors.greenAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          else
            GestureDetector(
              onTap: () => onToggle(isBlocked),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  isBlocked ? 'Blocked' : 'Allowed',
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── WebView settings sync ─────────────────────────────────────────────────────

Future<BrowserEngineConfig> _resolveCurrentConfig(WidgetRef ref) async {
  final theme = ref.read(themeProvider);
  final securityState = ref.read(securityProvider);

  // Always resolve adblock state — omitting it would clear content blockers
  // on the active tab whenever location/camera/desktop mode is toggled.
  List<AdBlockRule> adBlockRules = const [];
  if (securityState.isAdBlockEnabled) {
    try {
      adBlockRules = await ref.read(adBlockRulesProvider.future);
    } catch (e) {
      debugPrint('MIRA: AdBlock rules unavailable, proceeding without block list: $e');
    }
  }

  return BrowserEngineConfig(
    isDesktopMode: securityState.isDesktopMode,
    isDarkMode: theme.mode == ThemeMode.dark,
    isCameraBlocked: securityState.isCameraBlocked,
    isLocationBlocked: securityState.isLocationBlocked,
    adBlockRules: adBlockRules,
  );
}

Future<void> _applyConfigToEngine(
  BrowserEngine engine,
  BrowserEngineConfig config, {
  required bool forceReload,
}) async {
  try {
    await engine.updateSettings(config);
    if (forceReload) await engine.reload();
  } catch (e) {
    debugPrint('MIRA: Failed to update engine settings: $e');
  }
}

/// Applies the current theme/security config to only the *active* tab's
/// engine. Cheap — use this for cosmetic/low-stakes updates (e.g. theme
/// changes) where disturbing background tabs isn't warranted.
Future<void> applyMainScreenWebViewSettings(
  WidgetRef ref, {
  bool forceReload = false,
}) async {
  final engine = ref.read(browserChromeProvider).engine;
  if (engine == null) return;
  final config = await _resolveCurrentConfig(ref);
  await _applyConfigToEngine(engine, config, forceReload: forceReload);
}

/// Applies the current theme/security config to *every* instantiated tab —
/// normal and ghost, active and background alike. Required for
/// security-sensitive toggles (camera, location, desktop mode): a background
/// tab holding an already-granted camera/mic/location permission won't have
/// that permission revoked just by flipping the app-level setting, since the
/// engine only re-checks its blocked flags on the next permission request or
/// reload. Mirrors mainscreen.dart's `_applyAdBlockToAllTabs`, which applies
/// the same reload-everything reasoning for content blockers.
///
/// Reading `browserEngineProvider(id)` for a tab that has no live native
/// webview yet (e.g. still hibernated) is safe — it only constructs the Dart
/// wrapper; `updateSettings`/`reload` no-op internally until a controller is
/// actually attached.
Future<void> applySecuritySettingsToAllTabs(
  WidgetRef ref, {
  bool forceReload = true,
}) async {
  final config = await _resolveCurrentConfig(ref);

  final allTabIds = <String>{
    ...ref.read(tabsProvider).tabs.keys,
    ...ref.read(ghostTabsProvider).tabs.keys,
  };

  for (final id in allTabIds) {
    try {
      final engine = ref.read(browserEngineProvider(id));
      await _applyConfigToEngine(engine, config, forceReload: forceReload);
    } catch (e) {
      debugPrint('MIRA: Failed to update engine settings for tab $id: $e');
    }
  }
}


