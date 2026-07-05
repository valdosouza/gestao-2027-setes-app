import 'package:flutter/material.dart';

/// Encapsula [Scaffold] (decisão 11).
class SetesScaffold extends StatelessWidget {
  const SetesScaffold({
    required this.body,
    this.appBarTitle,
    this.appBarActions,
    this.drawer,
    super.key,
  });

  final Widget body;
  final String? appBarTitle;
  final List<Widget>? appBarActions;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarTitle != null
            ? AppBar(title: Text(appBarTitle!), actions: appBarActions)
            : null,
        drawer: drawer,
        body: body,
      );
}
