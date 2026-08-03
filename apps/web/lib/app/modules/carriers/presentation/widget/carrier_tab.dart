import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/object_carrier.dart';

/// Aba "Transportadora" — campos específicos de tb_carrier (skill
/// cadastro-entidade-fiscal.md; Onda 2 da Entidade Única). Mesmo contrato
/// das demais abas: recebe `value` + `onChanged` e o draft vive no bloc do
/// módulo. O papel só tem [ObjectCarrier.active] — checkbox fora da
/// sequência de Tab (contrato item 8).
class CarrierTab extends StatelessWidget {
  const CarrierTab({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ObjectCarrier value;
  final ValueChanged<ObjectCarrier> onChanged;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExcludeFocusTraversal(
            child: SetesCheckbox(
              label: 'forms.carrier.active'.tr(),
              value: value.active,
              onChanged: (v) => onChanged(value.copyWith(active: v ?? true)),
            ),
          ),
        ],
      );
}
