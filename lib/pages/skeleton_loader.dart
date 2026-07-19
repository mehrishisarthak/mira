import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qyx/core/notifiers/theme_notifier.dart';

class WebSkeletonLoader extends ConsumerStatefulWidget {
  const WebSkeletonLoader({super.key});

  @override
  ConsumerState<WebSkeletonLoader> createState() => _WebSkeletonLoaderState();
}

class _WebSkeletonLoaderState extends ConsumerState<WebSkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    // Never fades below 0.55. The old 0.3–0.6 range dropped the placeholders
    // close to the ground colour at the bottom of every cycle, which reads as
    // the screen flickering rather than as a shimmer.
    _animation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    // Placeholder fill, chosen for contrast against the ground it sits on.
    //
    // Dark was #2C2C2C against a #282828 (kMiraMatteBlack) background — a
    // 4/255 delta, i.e. invisible, and after the shimmer's opacity it was
    // closer still. #3D3D3D clears both the ground and the #323232 elevated
    // surface, so the placeholders actually read as blocks.
    //
    // Light (#E0E0E0 on white) was already fine and is unchanged.
    final baseColor = theme.mode == ThemeMode.light
        ? Colors.grey[300]!
        : const Color(0xFF3D3D3D);

    // FIX: SizedBox.expand forces the container to fill the entire Stack/Screen
    return SizedBox.expand(
      child: Container(
        color: theme.backgroundColor, 
        child: FadeTransition(
          opacity: _animation,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(), 
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Image / Banner Placeholder
                  _buildBox(height: 200, width: double.infinity, color: baseColor),
                  const SizedBox(height: 24),

                  // 2. Title Line
                  _buildBox(height: 24, width: 200, color: baseColor),
                  const SizedBox(height: 16),

                  // 3. Avatar + Meta row
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBox(height: 10, width: 100, color: baseColor),
                          const SizedBox(height: 6),
                          _buildBox(height: 10, width: 60, color: baseColor),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. Content Lines
                  for (int i = 0; i < 5; i++) ...[
                    _buildBox(height: 14, width: double.infinity, color: baseColor),
                    const SizedBox(height: 8),
                  ],
                  _buildBox(height: 14, width: 250, color: baseColor), 
                  
                  const SizedBox(height: 24),
                  
                  // 5. Secondary Image
                  _buildBox(height: 150, width: double.infinity, color: baseColor),
                  const SizedBox(height: 24),

                  // 6. More Text
                  for (int i = 0; i < 3; i++) ...[
                    _buildBox(height: 14, width: double.infinity, color: baseColor),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBox({required double height, required double width, required Color color}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
