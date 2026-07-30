import 'package:flutter/material.dart';

class RoutePlaceholderPage extends StatelessWidget {
  const RoutePlaceholderPage({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
