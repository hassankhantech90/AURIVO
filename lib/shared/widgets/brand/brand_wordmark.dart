import 'package:flutter/material.dart';

import 'brand_wordmark_path.dart';

/// The Pareezay.Hub wordmark, drawn from vector outlines so it stays crisp at
/// any size and follows the theme (black on light, light on dark) unless a
/// [color] is given. Sized by [height]; the width keeps the artwork's ratio.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.height = 24, this.color});

  /// The brand name, exposed to screen readers in place of the artwork.
  static const String brandName = 'Pareezay.Hub';

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paint = color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: brandName,
      image: true,
      child: SizedBox(
        height: height,
        width: height * brandWordmarkWidth / brandWordmarkHeight,
        child: CustomPaint(painter: _WordmarkPainter(paint)),
      ),
    );
  }
}

class _WordmarkPainter extends CustomPainter {
  _WordmarkPainter(this.color);

  final Color color;

  /// Parsed once and reused by every wordmark on screen.
  static final Path _path = _parse(brandWordmarkPath);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / brandWordmarkWidth,
      size.height / brandWordmarkHeight,
    );
    canvas.drawPath(_path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WordmarkPainter old) => old.color != color;

  /// Minimal parser for the absolute M / L / C / Q / Z commands the artwork
  /// was exported with.
  static Path _parse(String d) {
    final path = Path()..fillType = PathFillType.nonZero;
    final tokens = RegExp(
      r'[MLCQZ]|-?\d*\.?\d+',
    ).allMatches(d).map((m) => m[0]!);
    String? cmd;
    final nums = <double>[];
    void flush() {
      switch (cmd) {
        case 'M':
          path.moveTo(nums[0], nums[1]);
        case 'L':
          path.lineTo(nums[0], nums[1]);
        case 'C':
          path.cubicTo(nums[0], nums[1], nums[2], nums[3], nums[4], nums[5]);
        case 'Q':
          path.quadraticBezierTo(nums[0], nums[1], nums[2], nums[3]);
        case 'Z':
          path.close();
      }
      nums.clear();
    }

    for (final t in tokens) {
      if (RegExp(r'[MLCQZ]').hasMatch(t)) {
        if (cmd != null) flush();
        cmd = t;
      } else {
        nums.add(double.parse(t));
      }
    }
    if (cmd != null) flush();
    return path;
  }
}
