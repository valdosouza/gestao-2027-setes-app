import 'package:easy_localization/easy_localization.dart';

import '../../domain/entity/bank_slip_entity.dart';

/// Helpers de apresentação do módulo bank_slips (compartilhados entre a
/// página, o dialog de emissão e o detalhe).

/// ISO de hoje ('yyyy-MM-dd') — default de datas e destaque de vencidos.
String bankSlipTodayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// Valor decimal digitado ('1234,56' ou '1234.56') → double.
double? bankSlipParseDecimal(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

/// double → texto editável pt-BR ('1234,56').
String bankSlipDecimalText(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// Estado derivado → rótulo i18n ('Em aberto' / 'Liquidado' / 'Cancelado').
String bankSlipStateLabel(String state) => switch (state) {
      BankSlipStatus.settled => 'forms.bankSlip.stateSettled'.tr(),
      BankSlipStatus.cancelled => 'forms.bankSlip.stateCancelled'.tr(),
      _ => 'forms.bankSlip.stateOpen'.tr(),
    };

/// Kind do evento → rótulo i18n; kinds fora do catálogo desta onda (S/G do
/// canal) exibem o código cru.
String bankSlipEventKindLabel(String kind) => switch (kind) {
      BankSlipEventKind.issued => 'forms.bankSlip.eventIssued'.tr(),
      BankSlipEventKind.settled => 'forms.bankSlip.eventSettled'.tr(),
      BankSlipEventKind.cancelled => 'forms.bankSlip.eventCancelled'.tr(),
      BankSlipEventKind.reversed => 'forms.bankSlip.eventReversed'.tr(),
      _ => kind,
    };

/// Origem do evento → rótulo i18n (M manual / R retorno / A API).
String bankSlipEventSourceLabel(String? source) => switch (source) {
      'M' => 'forms.bankSlip.sourceManual'.tr(),
      'R' => 'forms.bankSlip.sourceReturn'.tr(),
      'A' => 'forms.bankSlip.sourceApi'.tr(),
      _ => source ?? '',
    };

/// Onda 2 — kind da VOZ DO BANCO → rótulo i18n (null = enviado, sem resposta).
String bankSlipRegistrationKindLabel(String? kind) => switch (kind) {
      BankSlipRegistrationKind.sent => 'forms.bankSlip.regSent'.tr(),
      BankSlipRegistrationKind.registered => 'forms.bankSlip.regRegistered'.tr(),
      BankSlipRegistrationKind.received => 'forms.bankSlip.regReceived'.tr(),
      BankSlipRegistrationKind.markedReceived => 'forms.bankSlip.regMarkedReceived'.tr(),
      BankSlipRegistrationKind.overdue => 'forms.bankSlip.regOverdue'.tr(),
      BankSlipRegistrationKind.protest => 'forms.bankSlip.regProtest'.tr(),
      BankSlipRegistrationKind.cancelled => 'forms.bankSlip.regCancelled'.tr(),
      BankSlipRegistrationKind.expired => 'forms.bankSlip.regExpired'.tr(),
      BankSlipRegistrationKind.failed => 'forms.bankSlip.regFailed'.tr(),
      BankSlipRegistrationKind.cancelRequested => 'forms.bankSlip.regCancelRequested'.tr(),
      BankSlipRegistrationKind.reapplied => 'forms.bankSlip.regReapplied'.tr(),
      null => 'forms.bankSlip.regInFlight'.tr(),
      _ => kind,
    };

/// Origem da fala do banco (W webhook · Q consulta · P resposta direta).
String bankSlipRegistrationSourceLabel(String? source) => switch (source) {
      'W' => 'forms.bankSlip.srcWebhook'.tr(),
      'Q' => 'forms.bankSlip.srcQuery'.tr(),
      'P' => 'forms.bankSlip.srcDirect'.tr(),
      _ => source ?? '',
    };
