import 'package:easy_localization/easy_localization.dart';

import '../../domain/entity/check_entity.dart';

/// Helpers de apresentação do módulo checks (compartilhados entre a
/// página, os dialogs de ação e o detalhe).

/// ISO de hoje ('yyyy-MM-dd') — default de datas nos dialogs de ação.
String checksTodayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// Valor decimal digitado ('1234,56' ou '1234.56') → double.
double? checksParseDecimal(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

/// double → texto editável pt-BR ('1234,56').
String checksDecimalText(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// Estado derivado → rótulo i18n.
String checkStatusLabel(String status) => switch (status) {
      CheckStatus.bank => 'forms.checks.stateBank'.tr(),
      CheckStatus.factoring => 'forms.checks.stateFactoring'.tr(),
      CheckStatus.supplier => 'forms.checks.stateSupplier'.tr(),
      CheckStatus.refunded => 'forms.checks.stateRefunded'.tr(),
      CheckStatus.collection => 'forms.checks.stateCollection'.tr(),
      _ => 'forms.checks.stateCustody'.tr(),
    };

/// Kind do evento → rótulo i18n.
String checkEventKindLabel(String kind) => switch (kind) {
      CheckEventKind.received => 'forms.checks.eventReceived'.tr(),
      CheckEventKind.bank => 'forms.checks.eventBank'.tr(),
      CheckEventKind.discounted => 'forms.checks.eventDiscounted'.tr(),
      CheckEventKind.paid => 'forms.checks.eventPaid'.tr(),
      CheckEventKind.refundReturn => 'forms.checks.eventRefundReturn'.tr(),
      CheckEventKind.goodReturn => 'forms.checks.eventGoodReturn'.tr(),
      CheckEventKind.returned => 'forms.checks.eventReturned'.tr(),
      CheckEventKind.reversed => 'forms.checks.eventReversed'.tr(),
      _ => kind,
    };

/// Kind do cabeçalho (P/T) → rótulo i18n.
String checkHeaderKindLabel(String kind) =>
    kind == CheckHeaderKind.third
        ? 'forms.checks.headerKindThird'.tr()
        : 'forms.checks.headerKindOwn'.tr();
