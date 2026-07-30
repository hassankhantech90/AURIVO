import 'package:flutter/material.dart';

import '../../../../core/theme/theme_exports.dart';

/// Lightweight shimmer effect for skeleton loading placeholders.
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    required this.child,
    this.duration = AppDurations.shimmer,
  });

  final Widget child;
  final Duration duration;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                AppColors.mistGrey,
                AppColors.pureWhite,
                AppColors.mistGrey,
              ],
              stops: const [0.25, 0.5, 0.75],
              begin: Alignment(-1 + _controller.value * 2, -0.3),
              end: Alignment(_controller.value * 2, 0.3),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
