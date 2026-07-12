import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/object_institution.dart';

/// Aba "Estabelecimento" — a ÚNICA aba não compartilhada do form
/// (skill cadastro-entidade-fiscal.md): campos específicos de tb_institution.
///
/// - schemaName: editável SÓ na inclusão (imutável na edição), padrão
///   `setes_<nome>`;
/// - active: readOnly na inclusão — quem ativa é a migração do schema no
///   backend (POST → commit → runMigrationsForSchema → active='S').
class InstitutionTab extends StatefulWidget {
  const InstitutionTab({
    required this.value,
    required this.creating,
    required this.onChanged,
    super.key,
  });

  final ObjectInstitution value;
  final bool creating;
  final ValueChanged<ObjectInstitution> onChanged;

  @override
  State<InstitutionTab> createState() => _InstitutionTabState();
}

class _InstitutionTabState extends State<InstitutionTab> {
  late final TextEditingController _schemaName;

  @override
  void initState() {
    super.initState();
    _schemaName = TextEditingController(text: widget.value.schemaName);
  }

  @override
  void dispose() {
    _schemaName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: SetesTextField(
                label: 'forms.institution.schemaName'.tr(),
                hint: 'forms.institution.schemaNameHint'.tr(),
                controller: _schemaName,
                readOnly: !widget.creating,
                autofocus: widget.creating,
                textInputAction: TextInputAction.done,
                onChanged: (t) =>
                    widget.onChanged(widget.value.copyWith(schemaName: t)),
              ),
            ),
            const SizedBox(height: 8),
            // Na inclusão o checkbox é somente leitura (ativação = migração).
            ExcludeFocusTraversal(
              child: AbsorbPointer(
                absorbing: widget.creating,
                child: Opacity(
                  opacity: widget.creating ? 0.6 : 1,
                  child: SetesCheckbox(
                    label: 'forms.institution.active'.tr(),
                    value: widget.value.active,
                    onChanged: (v) => widget.onChanged(
                        widget.value.copyWith(active: v ?? false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
