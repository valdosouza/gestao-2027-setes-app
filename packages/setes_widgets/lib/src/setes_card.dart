import 'package:flutter/material.dart';

/// Encapsula [Card] (decisão 11).
class SetesCard extends StatelessWidget {
  const SetesCard({required this.child, this.padding = const EdgeInsets.all(16), super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: padding, child: child));
}
