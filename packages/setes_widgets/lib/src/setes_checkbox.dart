import 'package:flutter/material.dart';

/// Encapsula [CheckboxListTile] (decisão 11) — usado na tela de escolha de
/// estabelecimento (marcar padrão — decisão 15) e nos privilégios do usuário.
class SetesCheckbox extends StatelessWidget {
  const SetesCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  /// false = somente leitura (ex.: obrigatoriedade técnica travada no
  /// painel de campos configuráveis — o cliente vê, mas não altera).
  final bool enabled;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        title: Text(label),
        value: value,
        onChanged: enabled ? onChanged : null,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
}
