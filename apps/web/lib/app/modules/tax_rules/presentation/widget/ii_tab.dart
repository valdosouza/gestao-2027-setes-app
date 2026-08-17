import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/tax_rule_draft.dart';

/// Aba II (Importação) — alíquotas do desembaraço aduaneiro: II, IRPJ,
/// CSLL, AFRMM e SISCOMEX (as duas últimas aceitam 5 casas decimais).
class IiTab extends StatefulWidget {
  const IiTab({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// null = tributo não definido (toggle desligado).
  final IiData? value;
  final ValueChanged<IiData?> onChanged;

  @override
  State<IiTab> createState() => _IiTabState();
}

class _IiTabState extends State<IiTab> {
  late final TextEditingController _ii;
  late final TextEditingController _irpj;
  late final TextEditingController _csll;
  late final TextEditingController _afrmm;
  late final TextEditingController _siscomex;

  /// Última fatia vista — religar o toggle restaura o que foi digitado.
  IiData _last = const IiData();

  @override
  void initState() {
    super.initState();
    _last = widget.value ?? const IiData();
    _ii = TextEditingController(text: _last.iiAliq);
    _irpj = TextEditingController(text: _last.irpjAliq);
    _csll = TextEditingController(text: _last.csllAliq);
    _afrmm = TextEditingController(text: _last.afrmmAliq);
    _siscomex = TextEditingController(text: _last.siscomexAliq);
  }

  @override
  void dispose() {
    _ii.dispose();
    _irpj.dispose();
    _csll.dispose();
    _afrmm.dispose();
    _siscomex.dispose();
    super.dispose();
  }

  void _emit(IiData updated) {
    _last = updated;
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final on = v != null;

    Widget numField({
      required int order,
      required String label,
      required TextEditingController controller,
      required ValueChanged<String> onChanged,
      bool last = false,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FocusTraversalOrder(
            order: NumericFocusOrder(order.toDouble()),
            child: SetesTextField(
              label: label,
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction:
                  last ? TextInputAction.done : TextInputAction.next,
              onChanged: onChanged,
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ExcludeFocusTraversal(
          child: SetesSwitch(
            label: 'forms.taxRules.defineIi'.tr(),
            subtitle: 'forms.taxRules.defineHint'.tr(),
            value: on,
            onChanged: (checked) =>
                widget.onChanged(checked ? _last : null),
          ),
        ),
        const SizedBox(height: 16),
        if (on)
          FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                numField(
                  order: 0,
                  label: 'forms.taxRules.iiAliq'.tr(),
                  controller: _ii,
                  onChanged: (t) => _emit(v.copyWith(iiAliq: t)),
                ),
                numField(
                  order: 1,
                  label: 'forms.taxRules.iiIrpjAliq'.tr(),
                  controller: _irpj,
                  onChanged: (t) => _emit(v.copyWith(irpjAliq: t)),
                ),
                numField(
                  order: 2,
                  label: 'forms.taxRules.iiCsllAliq'.tr(),
                  controller: _csll,
                  onChanged: (t) => _emit(v.copyWith(csllAliq: t)),
                ),
                numField(
                  order: 3,
                  label: 'forms.taxRules.iiAfrmmAliq'.tr(),
                  controller: _afrmm,
                  onChanged: (t) => _emit(v.copyWith(afrmmAliq: t)),
                ),
                numField(
                  order: 4,
                  label: 'forms.taxRules.iiSiscomexAliq'.tr(),
                  controller: _siscomex,
                  onChanged: (t) => _emit(v.copyWith(siscomexAliq: t)),
                  last: true,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
