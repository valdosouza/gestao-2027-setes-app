import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../session/crud_privileges.dart';

/// Casca do formulário de cadastro do CLIENTE com o privilégio de CRUD
/// aplicado (D-PV2 — `prompt_privilegios_interfaces.md`): a mesma
/// [SetesFormShell] do design system (que trata `onSave`/`onDelete` nulos
/// como "sem privilégio" — decisão 21), alimentada pelo ponto único
/// [CrudPrivileges]. A página só diz se o registro é NOVO.
///
/// [creating] true → o ✓ exige INSERIR; false → exige ALTERAR; a lixeira só
/// existe na edição e exige EXCLUIR.
class RegisterFormShell extends StatelessWidget {
  const RegisterFormShell({
    required this.title,
    required this.onBack,
    required this.child,
    required this.creating,
    this.onSave,
    this.onDelete,
    this.saving = false,
    this.actions,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  /// Registro NOVO (ainda sem id) × edição.
  final bool creating;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final bool saving;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => SetesFormShell(
        title: title,
        onBack: onBack,
        saving: saving,
        actions: actions,
        onSave: CrudPrivileges.canSave(creating: creating) ? onSave : null,
        onDelete: !creating && CrudPrivileges.canDelete ? onDelete : null,
        child: child,
      );
}
