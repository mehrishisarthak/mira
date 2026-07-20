import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PremiumGlassCard extends StatefulWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool enableHoverShader;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.height = 64.0,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.enableHoverShader = true,
  });

  @override
  State<PremiumGlassCard> createState() => _PremiumGlassCardState();
}

class _PremiumGlassCardState extends State<PremiumGlassCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  Offset _pointerPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      HapticFeedback.lightImpact();
      _scaleController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _scaleController.reverse();
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        onHover: (event) {
          if (widget.enableHoverShader) {
            setState(() => _pointerPosition = event.localPosition);
          }
        },
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
                child: Container(
                  width: double.infinity,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: Colors.white.withAlpha(20),
                      width: 1.0,
                    ),
                    boxShadow: _isHovered 
                      ? [BoxShadow(color: Colors.white.withAlpha(10), blurRadius: 10, spreadRadius: 2)]
                      : [],
                  ),
                  child: Stack(
                    children: [
                      if (_isHovered && widget.enableHoverShader)
                        Positioned.fill(
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return RadialGradient(
                                center: Alignment(
                                  (_pointerPosition.dx / bounds.width) * 2 - 1,
                                  (_pointerPosition.dy / bounds.height) * 2 - 1,
                                ),
                                radius: 1.5,
                                colors: [Colors.white.withAlpha(20), Colors.transparent],
                                stops: const [0.0, 0.6],
                              ).createShader(bounds);
                            },
                            child: Container(color: Colors.white),
                          ),
                        ),
                      Center(child: widget.child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
