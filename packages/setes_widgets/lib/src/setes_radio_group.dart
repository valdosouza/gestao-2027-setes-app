import 'package:flutter/material.dart';

/// Opção de um [SetesRadioGroup] — valor tipado + rótulo já traduzido
/// (design system puro: SEM easy_localization, o texto chega pronto).
class SetesRadioOption<T> {
  const SetesRadioOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Grupo de radioboxes (decisão 11) — escolha ÚNICA em domínio minúsculo
/// visível de uma vez (ex.: Sim/Não, Liberado/Bloqueado). Para domínios
/// maiores use SetesDropdown; para FK use SetesLookupField.
///
/// Renderiza como um campo do form (InputDecorator com label e borda no
/// padrão dos SetesTextField); [helperText] explica a escolha quando o
/// rótulo sozinho não basta. Fica fora da sequência de Tab (mesma regra
/// dos checkboxes — foco só por clique).
class SetesRadioGroup<T> extends StatelessWidget {
  const SetesRadioGroup({
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.helperText,
    super.key,
  });

  final String label;
  final List<SetesRadioOption<T>> options;
  final ValueChanged<T?> onChanged;

  /// Selecionado atual (null = nenhum — estado inicial permitido).
  final T? value;
  final String? helperText;

  @override
  Widget build(BuildContext context) => ExcludeFocusTraversal(
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: RadioGroup<T>(
            groupValue: value,
            onChanged: onChanged,
            child: Wrap(
              spacing: 16,
              children: [
                for (final option in options)
                  InkWell(
                    onTap: () => onChanged(option.value),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<T>(value: option.value),
                        Text(option.label),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
