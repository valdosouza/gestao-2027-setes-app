import 'package:flutter/material.dart';

/// Encapsula [CircularProgressIndicator] (decisão 11 — espelha o
/// custom_circular_progress_indicator do core de referência GestaoERPApps).
class SetesCircularProgressIndicator extends StatelessWidget {
  const SetesCircularProgressIndicator({this.strokeWidth = 4.0, super.key});

  final double strokeWidth;

  @override
  Widget build(BuildContext context) =>
      Center(child: CircularProgressIndicator(strokeWidth: strokeWidth));
}
