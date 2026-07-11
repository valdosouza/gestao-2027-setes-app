import 'package:flutter/material.dart';

/// Campo de FK (skill campo-lookup-fk.md): mostra a descrição do registro
/// relacionado (readOnly) + ícone de pesquisa (Icons.search) que abre a
/// lista de apoio. O id fica no estado do form, NUNCA é digitado.
///
/// Tabulação (skill criar-formulario-cadastro.md, item 8): campo readOnly
/// e botões de sufixo ficam FORA da sequência de Tab (foco só por clique).
class SetesLookupField extends StatelessWidget {
  const SetesLookupField({
    required this.label,
    required this.display,
    required this.onSearch,
    this.onClear,
    this.validatorMessage,
    super.key,
  });

  final String label;

  /// Descrição atual do registro escolhido ('' se nada escolhido).
  final String display;

  /// Abre a lista de apoio (showSetesLookup).
  final VoidCallback onSearch;

  /// Opcional: limpa a escolha (exibe Icons.close quando há valor).
  final VoidCallback? onClear;

  /// Se != null e nada escolhido, o Form.validate() exibe esta mensagem.
  final String? validatorMessage;

  @override
  Widget build(BuildContext context) => ExcludeFocusTraversal(
        child: TextFormField(
          key: ValueKey(display), // força rebuild quando a escolha muda
          initialValue: display,
          readOnly: true,
          onTap: onSearch, // clicar no campo também abre a lista
          validator: (_) => (validatorMessage != null && display.isEmpty)
              ? validatorMessage
              : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onClear != null && display.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClear,
                  ),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: onSearch,
                ),
              ],
            ),
          ),
        ),
      );
}
