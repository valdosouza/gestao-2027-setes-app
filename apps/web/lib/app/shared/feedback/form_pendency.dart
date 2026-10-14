import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'feedback.dart';

/// Mecânica UMA-PENDÊNCIA-POR-VEZ (R3) para formulários HÍBRIDOS — os que
/// vivem fora da fábrica RegisterFormPage (contratos, contas bancárias,
/// abas da cadeia fiscal, dialogs de sub-lista...). A fábrica embute a
/// MESMA mecânica; aqui ela vira peça reutilizável (Onda B do Framework
/// de Mensagens, prompt_framework_mensagens_validacao.md).

/// Um campo participante da validação, NA ORDEM em que aparece na tela.
class PendencyField {
  const PendencyField({
    required this.name,
    required this.validate,
    this.focusNode,
    this.fieldKey,
    this.beforeFocus,
  });

  /// Nome do campo no PAYLOAD (camelCase) — casa com o `fields[]` do
  /// envelope de erro do servidor ([showServerFieldFeedback]).
  final String name;

  /// Devolve a pendência (chave i18n ou texto já traduzido — a mecânica
  /// aplica .tr(), inócuo em texto pronto) ou null se o campo está ok.
  /// Lê o valor de onde ele mora (controller/estado da página).
  final String? Function() validate;

  /// Foco programático após o OK do dialog (campos de texto).
  final FocusNode? focusNode;

  /// Marca SÓ este campo inline (o SetesTextField precisa ter validator
  /// equivalente) — nunca a tela inteira vermelha (R3).
  final GlobalKey<FormFieldState<String>>? fieldKey;

  /// Prepara a tela para o foco — ex.: forms COMPOSTOS por abas trocam para
  /// a aba do campo aqui. Roda após o OK do dialog, ANTES do requestFocus;
  /// quando presente, marca/foco são adiados um frame (a aba de destino
  /// precisa montar o campo primeiro).
  final VoidCallback? beforeFocus;
}

/// R3 — percorre os campos NA ORDEM declarada; na PRIMEIRA pendência mostra
/// o dialog da ponte → OK → marca e foca SÓ o campo, e devolve false (o
/// salvar aborta; corrigiu, o próximo salvar mostra a próxima pendência).
/// Sem pendências devolve true.
Future<bool> ensureNoPendency(
    BuildContext context, List<PendencyField> fields) async {
  for (final field in fields) {
    final message = field.validate();
    if (message == null) continue;
    await showValidationFeedback(context, message.tr());
    if (context.mounted) _markAndFocus(field);
    return false;
  }
  return true;
}

/// Marca e foca SÓ o campo apontado; com [PendencyField.beforeFocus] (troca
/// de aba) o foco é adiado para o frame seguinte — o campo pode estar em
/// outra aba, desmontado até a troca acontecer.
void _markAndFocus(PendencyField field) {
  final beforeFocus = field.beforeFocus;
  if (beforeFocus == null) {
    field.fieldKey?.currentState?.validate(); // marca SÓ ele
    field.focusNode?.requestFocus();
    return;
  }
  beforeFocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    field.fieldKey?.currentState?.validate();
    field.focusNode?.requestFocus();
  });
}

/// Casa o name declarado no campo com o path do `fields[]` do servidor.
/// DTOs compostos (cadeia fiscal) devolvem paths ANINHADOS do Zod —
/// `entity.nameCompany`, `person.cpf`, `addresses.0.zipCode` — enquanto a
/// tela declara o name plano do campo; o casamento vale pelo path exato OU
/// pelo ÚLTIMO segmento.
bool matchesServerFieldPath(String fieldName, String serverPath) =>
    fieldName == serverPath || fieldName == serverPath.split('.').last;

/// Fallback quando o campo apontado pelo servidor NÃO existe na tela
/// (ex.: item de sub-lista): dialog de validação com campo + mensagem —
/// NUNCA só o "Validação falhou" genérico (skill mensagem-e-validacao).
Future<void> showUnanchoredServerField(
        BuildContext context, FailureField serverField) =>
    showValidationFeedback(
      context,
      'feedback.serverField'
          .tr(args: [serverField.field, serverField.message.tr()]),
    );

/// O TEXTO de uma falha com `fields[]` quando NÃO há campo montado para ancorar (o diálogo de ação já fechou — telas de processo).
/// P-04 (passeio logado da F2b, 2026-10-13) + D-F209 (Valdo, gates do passeio):
/// - 400 de DTO (`VALIDATION_FAILED` — `error` genérico "Validação falhou"): o campo + a mensagem dele, no formato da peça
///   [showUnanchoredServerField] (`feedback.serverField`) — a mensagem genérica não diz nada;
/// - os demais (ex.: 422 `FISCAL_DPS_INVALID`): a mensagem PRINCIPAL (diz o que corrigir e onde — "… corrija a regra de ISS") + a do
///   campo, só se a principal ainda não a contém (PSO-ADV-08 — sem eco); [all] = todos os campos, um por linha com o código (ex.: os
///   códigos E do fisco no `FISCAL_CANCEL_REFUSED`); sem [all], só o 1º (R3 — uma pendência por vez).
///
/// Gates do último delta (LD-ADV-08 = LD-SOC-06; LD-SOC-01 × LD-ADV-07): TOTAL — sem campos devolve a principal; o ramo do DTO é o
/// 400 (`statusCode == 400` + `VALIDATION_FAILED` — o setes-api usa o mesmo código em 422 com mensagem ESPECÍFICA, que fica) e com
/// `field` vazio cai no ramo geral; com [all] cada linha é só a MENSAGEM do campo (na forma REAL da recusa do fisco ela já leva o
/// código — `E1235: …` — e o `field` é o nome técnico `event`/`dps`, ruído).
String unanchoredFieldsText(Failure failure, {bool all = false}) {
  final main = failure.message.tr();
  if (failure.fields.isEmpty) return main;
  final first = failure.fields.first;
  if (failure.code == 'VALIDATION_FAILED' && failure.statusCode == 400 && first.field.isNotEmpty) {
    return 'feedback.serverField'.tr(args: [first.field, first.message.tr()]);
  }
  final lines = <String>[
    for (final f in all ? failure.fields : [first])
      if (!main.contains(f.message.tr())) '• ${f.message.tr()}',
  ];
  return lines.isEmpty ? main : '$main\n${lines.join('\n')}';
}

/// Equivalente local do `showServerFieldError` da fábrica para forms
/// híbridos: ancora o `fields[]` do envelope 400/409 no campo — dialog com
/// a message do servidor → OK → [PendencyField.beforeFocus] (aba certa) +
/// foco no campo apontado. Sem fields[] → feedback genérico da ponte; com
/// fields[] sem correspondência → [showUnanchoredServerField] (campo +
/// mensagem). Sem validate() inline: a regra é do servidor e a marca
/// vermelha local ficaria mentirosa.
Future<void> showServerFieldFeedback(
  BuildContext context,
  Failure failure,
  List<PendencyField> fields,
) async {
  if (failure.fields.isEmpty) return showFailureFeedback(context, failure);

  final serverField = failure.fields.first;
  PendencyField? match;
  for (final field in fields) {
    if (matchesServerFieldPath(field.name, serverField.field)) {
      match = field;
      break;
    }
  }
  if (match == null) return showUnanchoredServerField(context, serverField);
  final anchored = match;

  await showValidationFeedback(context, serverField.message.tr());
  if (!context.mounted) return;
  final beforeFocus = anchored.beforeFocus;
  if (beforeFocus == null) {
    anchored.focusNode?.requestFocus();
    return;
  }
  beforeFocus();
  WidgetsBinding.instance
      .addPostFrameCallback((_) => anchored.focusNode?.requestFocus());
}
