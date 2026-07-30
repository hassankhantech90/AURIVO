import 'package:flutter/material.dart';

/// Hero helper that centralizes tag usage for shared image and card transitions.
class LuxuryHero extends StatelessWidget {
  const LuxuryHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(tag: tag, child: child);
  }
}
