import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../error/failure.dart';

/// Feedback das telas de AUTH (Framework de Mensagens — skill
/// mensagem-e-validacao.md). O core NÃO enxerga a ponte
/// `app/shared/feedback/` do app; nesta superfície pré-login o desfecho vai
/// DIRETO ao apresentador do design system ([showSetesMessage]) com textos
/// já traduzidos — mesmo contrato da ponte (R1/R7): a natureza deriva do
/// desfecho, nunca de campo de severidade.

/// Erro TÉCNICO (R7): rastro de suporte presente, status >= 500 ou queda de
/// rede. O resto (400/401/409...) é corrigível pelo usuário.
bool isTechnicalFailure(Failure failure) =>
    failure.supportRef != null ||
    (failure.statusCode ?? 0) >= 500 ||
    failure is NetworkFailure;

/// Falha = SEMPRE dialog (R1): técnico com linha discreta do código de
/// suporte (R2); corrigível vira dialog de validação. `message.tr()`: os
/// defaults do core são chaves `core.errors.*`/`auth.*` — chave inexistente
/// devolve a própria string (PT do backend passa intacto).
Future<void> showAuthFailureDialog(BuildContext context, Failure failure) {
  if (isTechnicalFailure(failure)) {
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

/// Pendência LOCAL de validação (R3 — UMA por vez): dialog + quem chama
/// devolve o foco ao campo pendente. [messageKey] é chave i18n.
Future<void> showAuthValidationDialog(BuildContext context, String messageKey) =>
    showSetesMessage(
      context,
      kind: SetesMessageKind.validation,
      title: 'feedback.validationTitle'.tr(),
      message: messageKey.tr(),
      okLabel: 'register.ok'.tr(),
    );

/// Sucesso = SnackBar (R1), via apresentador. [messageKey] é chave i18n.
Future<void> showAuthSuccessFeedback(BuildContext context, String messageKey) =>
    showSetesMessage(
      context,
      kind: SetesMessageKind.success,
      message: messageKey.tr(),
      okLabel: 'register.ok'.tr(),
    );
