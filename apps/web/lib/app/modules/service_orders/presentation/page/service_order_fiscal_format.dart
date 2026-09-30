import 'package:easy_localization/easy_localization.dart';

import '../../domain/entity/service_order_fiscal_entity.dart';

/// Rótulos traduzidos da seção "No fisco" (Onda 3 — NFS-e pelo ADN):
/// kind da voz do fisco, origem da fala e ambiente da transmissão. Molde do
/// bank_slip_format.dart; chaves em forms.serviceOrder.fiscal*.

/// Situação da transmissão pelo kind do ÚLTIMO evento; null = enviado sem
/// resposta (em andamento).
String fiscalKindLabel(String? kind) => switch (kind) {
      FiscalTransmissionKind.sent => 'forms.serviceOrder.fiscalKindSent'.tr(),
      FiscalTransmissionKind.authorized =>
        'forms.serviceOrder.fiscalKindAuthorized'.tr(),
      FiscalTransmissionKind.rejected =>
        'forms.serviceOrder.fiscalKindRejected'.tr(),
      FiscalTransmissionKind.cancelled =>
        'forms.serviceOrder.fiscalKindCancelled'.tr(),
      FiscalTransmissionKind.cancelInFlight =>
        'forms.serviceOrder.fiscalKindCancelInFlight'.tr(),
      FiscalTransmissionKind.failed => 'forms.serviceOrder.fiscalKindFailed'.tr(),
      null => 'forms.serviceOrder.fiscalKindInFlight'.tr(),
      _ => kind,
    };

/// Origem da fala do fisco (P resposta direta · Q consulta).
String fiscalSourceLabel(String? source) => switch (source) {
      'P' => 'forms.serviceOrder.fiscalSrcDirect'.tr(),
      'Q' => 'forms.serviceOrder.fiscalSrcQuery'.tr(),
      _ => source ?? '',
    };

/// Ambiente da transmissão (H produção restrita · P produção).
String fiscalEnvironmentLabel(String environment) => environment == 'P'
    ? 'forms.serviceOrder.fiscalEnvProduction'.tr()
    : 'forms.serviceOrder.fiscalEnvRestricted'.tr();

/// Data/hora do fisco (ISO 'yyyy-MM-ddTHH:mm:ss...') → 'dd/MM/yyyy HH:mm';
/// só data → 'dd/MM/yyyy'; formato desconhecido passa intacto.
String fiscalDateTimeToDisplay(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?')
      .firstMatch(iso);
  if (m == null) return iso;
  final date = '${m.group(3)}/${m.group(2)}/${m.group(1)}';
  return m.group(4) == null ? date : '$date ${m.group(4)}:${m.group(5)}';
}

/// Selo fiscal da linha da lista (situação da transmissão VIGENTE, vinda da
/// API — o mesmo leitor da seção "No fisco"). Autorizada com número mostra o
/// nº da NFS-e; homologação é sempre sinalizada (não vale como documento).
String fiscalSealLabel(String state, {String? nfseNumber, String? environment}) {
  final base = switch (state) {
    'none' => 'forms.serviceOrder.fiscalStateNone'.tr(),
    'authorized' => (nfseNumber == null || nfseNumber.isEmpty)
        ? 'forms.serviceOrder.fiscalKindAuthorized'.tr()
        : 'forms.serviceOrder.fiscalSealAuthorized'.tr(args: [nfseNumber]),
    'rejected' => 'forms.serviceOrder.fiscalKindRejected'.tr(),
    'failed' => 'forms.serviceOrder.fiscalKindFailed'.tr(),
    'cancelled' => 'forms.serviceOrder.fiscalKindCancelled'.tr(),
    'cancel_in_flight' => 'forms.serviceOrder.fiscalKindCancelInFlight'.tr(),
    _ => 'forms.serviceOrder.fiscalKindInFlight'.tr(),
  };
  return environment == 'H'
      ? '$base · ${'forms.serviceOrder.fiscalEnvRestricted'.tr()}'
      : base;
}
