import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// PONTE desfecho → apresentação (peça F do Framework de Mensagens —
/// prompt_framework_mensagens_validacao.md).
///
/// As telas NUNCA chamam ScaffoldMessenger/AlertDialog diretamente: entregam
/// o DESFECHO (sucesso, Failure, pendência ou pergunta) e a ponte decide
/// severidade + canal via o apresentador do design system (peça E). É aqui
/// que o i18n acontece — o design system recebe textos prontos.

/// Sucesso = SnackBar (R1). [messageKey] é chave i18n ('register.saved'...).
Future<void> showSuccessFeedback(
  BuildContext context,
  String messageKey, {
  List<String>? args,
}) =>
    showSetesMessage(
      context,
      kind: SetesMessageKind.success,
      message: messageKey.tr(args: args),
      okLabel: 'register.ok'.tr(),
    );

/// Falha = SEMPRE dialog (R1). A natureza deriva do desfecho, nunca de um
/// campo de severidade (R7): supportRef presente, status >= 500 ou queda de
/// rede = erro TÉCNICO (com linha discreta do código de suporte); o resto
/// (400/409...) = corrigível pelo usuário → validation.
///
/// `message.tr()`: defaults do core são chaves `core.errors.*`; chave
/// inexistente devolve a própria string — mensagens PT do backend passam
/// intactas.
Future<void> showFailureFeedback(BuildContext context, Failure failure) {
  final technical = failure.supportRef != null ||
      (failure.statusCode ?? 0) >= 500 ||
      failure is NetworkFailure;

  if (technical) {
    return showSetesMessage(
      context,
      kind: SetesMessageKind.error,
      title: 'feedback.errorTitle'.tr(),
      message: failure.message.tr(),
      okLabel: 'register.ok'.tr(),
      refText: failure.supportRef == null
          ? null
          : 'feedback.supportRef'.tr(args: [failure.supportRef!]),
    );
  }
  return showSetesMessage(
    context,
    kind: SetesMessageKind.validation,
    title: 'feedback.validationTitle'.tr(),
    message: failure.message.tr(),
    okLabel: 'register.ok'.tr(),
  );
}

/// Pendência LOCAL do formulário (R3 — uma por vez). [message] já traduzida
/// (quem valida traduz a chave do setes_validators antes de chamar).
Future<void> showValidationFeedback(BuildContext context, String message) =>
    showSetesMessage(
      context,
      kind: SetesMessageKind.validation,
      title: 'feedback.validationTitle'.tr(),
      message: message,
      okLabel: 'register.ok'.tr(),
    );

/// Pergunta com decisão 3-way tipada (R4). Labels default: register.yes /
/// register.cancel; [noLabel] null = sem ação alternativa (só Sim/Cancelar —
/// ex.: confirmação de exclusão); passe 'register.no'.tr() quando o Não
/// gerar OUTRA ação.
Future<SetesDecision> askDecision(
  BuildContext context, {
  required String message,
  String? title,
  String? yesLabel,
  String? noLabel,
  String? cancelLabel,
}) =>
    showSetesDecision(
      context,
      message: message,
      title: title,
      yesLabel: yesLabel ?? 'register.yes'.tr(),
      noLabel: noLabel,
      cancelLabel: cancelLabel ?? 'register.cancel'.tr(),
    );
