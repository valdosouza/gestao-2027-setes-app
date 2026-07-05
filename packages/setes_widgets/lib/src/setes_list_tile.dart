import 'package:flutter/material.dart';

/// Encapsula [ListTile] (decisão 11 — ex. canônico do prompt).
class SetesListTile extends StatelessWidget {
  const SetesListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        selected: selected,
        onTap: onTap,
      );
}
