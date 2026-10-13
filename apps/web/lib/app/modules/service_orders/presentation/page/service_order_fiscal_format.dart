import 'package:easy_localization/easy_localization.dart';

import '../../domain/entity/service_order_fiscal_entity.dart';

/// Rótulos traduzidos da seção "No fisco" — kind da voz (só RÓTULO — D-F142),
/// estado da NFS-e (o `state` do servidor), origem da fala e ambiente. Chaves
/// em forms.serviceOrder.fiscal*.

/// Rótulo do kind de UMA fala do fisco (linha do tempo); null = enviado sem
/// resposta. Kind desconhecido passa cru (API mais nova que o build).
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
      // D-N17: o cancelamento NÃO aconteceu — a NFS-e segue autorizada
      FiscalTransmissionKind.notCancelled =>
        'forms.serviceOrder.fiscalKindNotCancelled'.tr(),
      null => 'forms.serviceOrder.fiscalKindInFlight'.tr(),
      _ => kind,
    };

/// Origem da fala do fisco (P resposta direta · Q consulta).
String fiscalSourceLabel(String? source) => switch (source) {
      'P' => 'forms.serviceOrder.fiscalSrcDirect'.tr(),
      'Q' => 'forms.serviceOrder.fiscalSrcQuery'.tr(),
      _ => source ?? '',
    };

/// Ambiente da tentativa (H produção restrita · P produção) — só rótulo.
String fiscalEnvironmentLabel(String? environment) => switch (environment) {
      'P' => 'forms.serviceOrder.fiscalEnvProduction'.tr(),
      'H' => 'forms.serviceOrder.fiscalEnvRestricted'.tr(),
      _ => '',
    };

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

/// Rótulo do ESTADO da NFS-e (o `state` derivado pelo servidor) — na linha da
/// lista e na seção. Autorizada com número mostra o nº; homologação é sempre
/// sinalizada (não vale como documento). `unavailable` = a voz do fisco
/// ilegível agora (D-F130 — a lista não cai). Estado desconhecido = neutro.
String fiscalSealLabel(String state, {String? nfseNumber, String? environment}) {
  final base = switch (state) {
    NfseState.none => 'forms.serviceOrder.fiscalStateNone'.tr(),
    NfseState.authorized => (nfseNumber == null || nfseNumber.isEmpty)
        ? 'forms.serviceOrder.fiscalKindAuthorized'.tr()
        : 'forms.serviceOrder.fiscalSealAuthorized'.tr(args: [nfseNumber]),
    NfseState.rejected => 'forms.serviceOrder.fiscalKindRejected'.tr(),
    NfseState.failed => 'forms.serviceOrder.fiscalKindFailed'.tr(),
    NfseState.cancelled => 'forms.serviceOrder.fiscalKindCancelled'.tr(),
    NfseState.cancelInFlight => 'forms.serviceOrder.fiscalKindCancelInFlight'.tr(),
    NfseState.inFlight || NfseState.processing => 'forms.serviceOrder.fiscalKindInFlight'.tr(),
    NfseState.unavailable => 'forms.serviceOrder.fiscalStateUnavailable'.tr(),
    _ => 'forms.serviceOrder.fiscalStateUnknown'.tr(),
  };
  return environment == 'H'
      ? '$base · ${'forms.serviceOrder.fiscalEnvRestricted'.tr()}'
      : base;
}
