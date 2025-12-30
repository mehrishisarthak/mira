import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/theme_model.dart';

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
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final baseColor = theme.mode == ThemeMode.light 
        ? Colors.grey[300]! 
        : const Color(0xFF2C2C2C); 

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