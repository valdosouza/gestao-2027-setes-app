import 'package:flutter/material.dart';

/// Encapsula [Scaffold] (decisão 11).
class SetesScaffold extends StatelessWidget {
  const SetesScaffold({
    required this.body,
    this.appBarTitle,
    this.appBarActions,
    this.appBarLeading,
    this.drawer,
    super.key,
  });

  final Widget body;
  final String? appBarTitle;
  final List<Widget>? appBarActions;

  /// Ex.: logomarca da institution (decisão 16).
  final Widget? appBarLeading;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBarTitle != null
            ? AppBar(
                title: Text(appBarTitle!),
                actions: appBarActions,
                leading: appBarLeading)
            : null,
        drawer: drawer,
        body: body,
      );
}
