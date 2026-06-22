import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/constants/app_fonts.dart';

import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

class BrandingScreen extends ConsumerWidget {
  const BrandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGhost = ref.watch(isGhostModeProvider);
    return isGhost ? const _GhostLandingPage() : const _NormalSpeedDial();
  }
}

// ── Ghost Landing ─────────────────────────────────────────────────────────────

class _GhostLandingPage extends ConsumerStatefulWidget {
  const _GhostLandingPage();

  @override
  ConsumerState<_GhostLandingPage> createState() => _GhostLandingPageState();
}

class _GhostLandingPageState extends ConsumerState<_GhostLandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigate(String query) {
    if (query.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(ghostTabsProvider.notifier).updateUrl(query.trim());
    final engine = ref.read(activeBrowserEngineProvider);
    engine?.loadUrl(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      color: kMiraMatteBlack,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top identity block ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    // Pulsing icon
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Icon(
                        Icons.visibility_outlined,
                        size: 36,
                        color: Colors.redAccent.withValues(alpha: _pulse.value * 0.8),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Ghost\nProtocol.',
                      style: jetBrainsMono(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Browse. Then vanish.',
                      style: jetBrainsMono(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.35),
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Protected items
                    _GhostItem(
                      icon: Icons.history_toggle_off,
                      label: 'History not saved',
                      protected: true,
                    ),
                    _GhostItem(
                      icon: Icons.cookie_outlined,
                      label: 'Cookies cleared on close',
                      protected: true,
                    ),
                    _GhostItem(
                      icon: Icons.cached,
                      label: 'Cache wiped on exit',
                      protected: true,
                    ),

                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.06)),
                    const SizedBox(height: 16),

                    _GhostItem(
                      icon: Icons.wifi_tethering,
                      label: 'Your ISP can still see activity',
                      protected: false,
                    ),
                    _GhostItem(
                      icon: Icons.download_outlined,
                      label: 'Downloads stay on device',
                      protected: false,
                    ),

                    const SizedBox(height: 40),

                    // Quick launch buttons
                    Text(
                      'QUICK START',
                      style: jetBrainsMono(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.25),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickLaunchChip(
                          label: 'DuckDuckGo',
                          url: 'https://duckduckgo.com',
                          onTap: _navigate,
                        ),
                        _QuickLaunchChip(
                          label: 'Brave Search',
                          url: 'https://search.brave.com',
                          onTap: _navigate,
                        ),
                        _QuickLaunchChip(
                          label: 'ProtonMail',
                          url: 'https://mail.proton.me',
                          onTap: _navigate,
                        ),
                      ],
                    ),

                    SizedBox(height: bottom + 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool protected;

  const _GhostItem({
    required this.icon,
    required this.label,
    required this.protected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: protected
                ? Colors.redAccent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: jetBrainsMono(
              fontSize: 13,
              color: protected
                  ? Colors.white.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.22),
              height: 1.4,
            ),
          ),
          if (protected) ...[
            const Spacer(),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickLaunchChip extends StatelessWidget {
  final String label;
  final String url;
  final void Function(String) onTap;

  const _QuickLaunchChip({
    required this.label,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(20),
          color: Colors.redAccent.withValues(alpha: 0.05),
        ),
        child: Text(
          label,
          style: jetBrainsMono(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ── Normal Speed Dial ─────────────────────────────────────────────────────────

class _NormalSpeedDial extends ConsumerWidget {
  const _NormalSpeedDial();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning.';
    if (h < 17) return 'Good afternoon.';
    return 'Good evening.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final isLight = theme.mode == ThemeMode.light;
    final textColor = isLight ? kMiraInkPrimary : Colors.white;
    final accent = theme.primaryColor;

    const items = [
      _DialData('YouTube', Icons.play_circle_outline, 'https://m.youtube.com'),
      _DialData('Reddit', Icons.reddit, 'https://www.reddit.com'),
      _DialData('GitHub', Icons.code, 'https://github.com'),
      _DialData('Wikipedia', Icons.language, 'https://en.wikipedia.org'),
      _DialData('DuckDuckGo', Icons.search, 'https://duckduckgo.com'),
      _DialData('Hacker News', Icons.newspaper, 'https://news.ycombinator.com'),
    ];

    return Container(
      color: theme.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: jetBrainsMono(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Where to?',
                      style: jetBrainsMono(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.35),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Speed dial grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _DialTile(
                    data: items[i],
                    accent: accent,
                    textColor: textColor,
                    ref: ref,
                  ),
                  childCount: items.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _DialData {
  final String label;
  final IconData icon;
  final String url;
  const _DialData(this.label, this.icon, this.url);
}

class _DialTile extends StatefulWidget {
  final _DialData data;
  final Color accent;
  final Color textColor;
  final WidgetRef ref;

  const _DialTile({
    required this.data,
    required this.accent,
    required this.textColor,
    required this.ref,
  });

  @override
  State<_DialTile> createState() => _DialTileState();
}

class _DialTileState extends State<_DialTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tapCtrl.forward(),
      onTapUp: (_) async {
        await _tapCtrl.reverse();
        widget.ref.read(tabsProvider.notifier).updateUrl(widget.data.url);
        HapticFeedback.lightImpact();
      },
      onTapCancel: () => _tapCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.data.icon,
                size: 28,
                color: widget.textColor.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 8),
              Text(
                widget.data.label,
                style: jetBrainsMono(
                  fontSize: 10,
                  color: widget.textColor.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
