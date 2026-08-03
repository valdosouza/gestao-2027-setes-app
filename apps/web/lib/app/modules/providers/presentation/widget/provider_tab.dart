import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/object_provider.dart';

/// Aba "Fornecedor" — campos específicos de tb_provider (skill
/// cadastro-entidade-fiscal.md; Onda 3 da Entidade Única). Mesmo contrato
/// das demais abas: recebe `value` + `onChanged` e o draft vive no bloc do
/// módulo. O papel só tem [ObjectProvider.active] — checkbox fora da
/// sequência de Tab (contrato item 8).
class ProviderTab extends StatelessWidget {
  const ProviderTab({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ObjectProvider value;
  final ValueChanged<ObjectProvider> onChanged;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExcludeFocusTraversal(
            child: SetesCheckbox(
              label: 'forms.provider.active'.tr(),
              value: value.active,
              onChanged: (v) => onChanged(value.copyWith(active: v ?? true)),
            ),
          ),
        ],
      );
}
