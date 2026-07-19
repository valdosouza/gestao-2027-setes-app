import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../feedback/feedback.dart';

/// Utilitários comuns das abas de lista da cadeia de entidade fiscal
/// (Endereços/Fones/Redes Sociais) — CRUD inline no padrão do
/// customer_register: lista + dialog de adicionar/editar + remover com
/// confirmação. Kind é PK junto com o id — único por lista.

/// Confirmação de remoção via decisão TIPADA da ponte (R4 do Framework de
/// Mensagens): Sim = excluir; Cancelar (ou fechar) = nada. Sem ação
/// alternativa → sem botão Não.
Future<bool> confirmEntityItemDelete(BuildContext context) async {
  final decision = await askDecision(
    context,
    message: 'register.confirmDelete'.tr(),
    yesLabel: 'register.delete'.tr(),
  );
  return decision == SetesDecision.yes;
}

/// Validator do campo kind: obrigatório e ÚNICO na lista (PK id+kind).
String? Function(String?) kindValidator(Set<String> takenKinds) =>
    (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return 'register.required'.tr();
      if (takenKinds.contains(text)) return 'register.duplicateKind'.tr();
      return null;
    };

/// Casca das abas de lista: lista separada + FAB (Icons.add) para incluir.
class EntityListScaffold extends StatelessWidget {
  const EntityListScaffold({
    required this.itemCount,
    required this.itemBuilder,
    required this.onAdd,
    required this.heroTag,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback onAdd;

  /// FABs de abas diferentes precisam de heroTag próprio.
  final String heroTag;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          heroTag: heroTag,
          onPressed: onAdd,
          child: const Icon(Icons.add),
        ),
        body: itemCount == 0
            ? Center(child: SetesText('register.emptyList'.tr()))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: itemCount,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: itemBuilder,
              ),
      );
}
