import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// D-PV32 (Valdo 2026-10-20 — `prompt_privilegios_interfaces.md`): o PRÓPRIO
/// estabelecimento pode ser papel (cliente interno, fornecedor de si mesma),
/// mas a CADEIA (dados da empresa, endereços, contatos) e a aba TRIBUTAÇÃO
/// ficam SOMENTE LEITURA — o emitente se edita pelo Meu Estabelecimento.
/// A regra é da API (409 OWN_ESTABLISHMENT_READ_ONLY se o corpo tentar mudar);
/// aqui é UX: a aba congela com a frase. Os campos PRÓPRIOS do papel
/// (carteira, vendedor, limite, ativo…) ficam fora deste envelope.
class OwnEstablishmentFrozen extends StatelessWidget {
  const OwnEstablishmentFrozen({
    required this.frozen,
    required this.child,
    super.key,
  });

  /// `ownEstablishment` do GET do papel.
  final bool frozen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!frozen) return child;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: SetesText('register.ownEstablishment'.tr())),
              ],
            ),
          ),
        ),
        Expanded(
          child: AbsorbPointer(
            absorbing: true,
            child: Opacity(opacity: 0.6, child: child),
          ),
        ),
      ],
    );
  }
}

/// Congela, pelos ÍNDICES, as abas da CADEIA/TRIBUTAÇÃO de um `TabBarView`
/// de cadastro de papel (as abas próprias do papel ficam editáveis).
List<Widget> freezeChainTabs({
  required List<Widget> tabs,
  required bool frozen,
  required Set<int> indexes,
}) =>
    [
      for (var i = 0; i < tabs.length; i++)
        indexes.contains(i)
            ? OwnEstablishmentFrozen(frozen: frozen, child: tabs[i])
            : tabs[i],
    ];
