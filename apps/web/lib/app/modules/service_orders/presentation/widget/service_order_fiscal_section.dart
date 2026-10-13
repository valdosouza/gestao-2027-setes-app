import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/service_order_entity.dart';
import '../../domain/entity/service_order_fiscal_entity.dart';
import '../bloc/service_order_bloc.dart';
import '../page/service_order_fiscal_format.dart';

/// Seção "No fisco" do detalhe da OS FATURADA — F2b (D-F139/D-F142),
/// extraída da página para ser testada sozinha. DUAS fontes, DUAS falhas: a
/// VOZ do fisco (nfse-api — estado, tentativa VIGENTE pelo servidor, linha do
/// tempo) e o EFEITO na nota (ERP). Botões pelo `state` do servidor, pelo
/// `effect` e pelo privilégio — nunca por coluna crua; o kind é só rótulo.
/// Todo cancelamento passa pelo PLANO (D-F140) — os callbacks só pedem.
class ServiceOrderFiscalSection extends StatelessWidget {
  const ServiceOrderFiscalSection({
    required this.state,
    required this.onTransmit,
    required this.onFiscalRefresh,
    required this.onFiscalXml,
    required this.onFiscalDanfse,
    required this.onCancelInvoice,
    required this.onKeepInvoice,
    super.key,
  });

  final ServiceOrderDetailState state;
  final VoidCallback onTransmit;
  final VoidCallback onFiscalRefresh;
  final VoidCallback onFiscalXml;
  final VoidCallback onFiscalDanfse;

  /// Cancelar NFS-e / Aplicar o cancelamento / Cancelar nota — o MESMO fluxo
  /// pelo plano (D-F140).
  final VoidCallback onCancelInvoice;

  /// D-F67 — "Manter a nota" com NFS-e substituída no fisco.
  final VoidCallback onKeepInvoice;

  ServiceOrderFull get order => state.order;
  bool get busy => state.saving;
  ServiceOrderFiscalView? get fiscal => state.fiscal;
  ServiceOrderFiscalEffect? get effect => state.effect;

  Widget _row(String text, {TextStyle? style}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SetesText(text, style: style),
      );

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      await showSuccessFeedback(context, 'forms.serviceOrder.fiscalCopied');
    }
  }

  /// D-F67: substituída no fisco e ainda sem decisão — o ERP diz (`effect`
  /// = decide; D-F142: nunca derivado no app); nota cancelada = o humano já
  /// decidiu cancelar.
  bool get _substitutionUndecided =>
      effect?.effect == FiscalEffect.decide && !order.isCancelled;

  /// D-F67: aviso em destaque (cor de erro) + chave da NFS-e SUBSTITUTA,
  /// somente leitura com copiar. Sem a chave (XML do evento indisponível) o
  /// campo diz "indisponível" e não oferece cópia. O texto "até você decidir"
  /// só aparece enquanto a decisão está aberta.
  List<Widget> _buildSubstitution(
      BuildContext context, ServiceOrderFiscalSubstitution substitution) {
    final theme = Theme.of(context);
    final key = substitution.substituteAccessKey;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: SetesText(
          _substitutionUndecided
              ? 'forms.serviceOrder.fiscalSubstitutedRow'.tr()
              : 'forms.serviceOrder.fiscalSubstitutedDecidedRow'.tr(),
          style: TextStyle(
              color: theme.colorScheme.error, fontWeight: FontWeight.w600),
        ),
      ),
      SetesTextField(
        label: 'forms.serviceOrder.fiscalSubstituteAccessKey'.tr(),
        controller: TextEditingController(
            text: substitution.hasSubstituteKey
                ? key
                : 'forms.serviceOrder.fiscalSubstituteUnavailable'.tr()),
        readOnly: true,
        suffixIcon: substitution.hasSubstituteKey ? Icons.copy : null,
        onSuffixPressed: substitution.hasSubstituteKey
            ? () => _copy(context, key!)
            : null,
      ),
    ];
  }

  /// O EFEITO da voz do fisco na nota (ERP — D-F114): `apply` e `cancel`
  /// pedem ação humana (cor de erro); `decide` é o bloco da substituição;
  /// `none`/desconhecido = nada a dizer.
  Widget? _effectRow(BuildContext context, ServiceOrderFiscalEffect fx) {
    final key = switch (fx.effect) {
      FiscalEffect.apply => 'forms.serviceOrder.fiscalEffectApplyRow',
      FiscalEffect.cancel => 'forms.serviceOrder.fiscalEffectCancelRow',
      _ => null,
    };
    if (key == null || order.isCancelled) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SetesText(key.tr(),
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
    );
  }

  /// Seção "No fisco" — F2b (D-F139/D-F142): DUAS fontes, DUAS falhas. A VOZ
  /// do fisco vem da nfse-api (estado, tentativa VIGENTE pelo servidor, linha
  /// do tempo); o EFEITO na nota vem do ERP. Botões pelo `state` do servidor,
  /// pelo `effect` e pelo privilégio — nunca por coluna crua; o kind é só
  /// rótulo. Todo cancelamento passa pelo PLANO (D-F140).
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = fiscal;
    final tx = view?.current;
    final failure = state.fiscalFailure;
    final fx = effect;
    final canCancel = CurrentInterface.can('CANCELAR');
    final effectRow = fx == null ? null : _effectRow(context, fx);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SetesText.title('forms.serviceOrder.fiscalSection'.tr()),
        const SizedBox(height: 8),
        SetesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failure != null)
                _row(
                  'forms.serviceOrder.fiscalUnavailable'
                      .tr(args: [failure.message.tr()]),
                  style: TextStyle(color: theme.colorScheme.error),
                )
              else if (tx == null)
                _row(view == null || view.state == NfseState.none
                    ? 'forms.serviceOrder.fiscalNotTransmitted'.tr()
                    : fiscalSealLabel(view.state))
              else ...[
                _row('forms.serviceOrder.fiscalAttemptRow'.tr(args: [
                  '${tx.attempt}',
                  fiscalEnvironmentLabel(tx.environment),
                ])),
                _row('forms.serviceOrder.fiscalStatusRow'.tr(args: [
                  fiscalSealLabel(view!.state),
                  [tx.lastCode, tx.lastMessage]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' — '),
                ])),
                if (tx.dpsId != null)
                  _row('forms.serviceOrder.fiscalDpsRow'.tr(args: [tx.dpsId!])),
                if (tx.dhProc != null)
                  _row('forms.serviceOrder.fiscalDhProcRow'
                      .tr(args: [fiscalDateTimeToDisplay(tx.dhProc)])),
                if (tx.lastQueriedAt != null)
                  _row('forms.serviceOrder.fiscalQueriedRow'
                      .tr(args: [fiscalDateTimeToDisplay(tx.lastQueriedAt)])),
                if (tx.nfseNumber != null)
                  SetesTextField(
                    label: 'forms.serviceOrder.fiscalNfseNumber'.tr(),
                    controller: TextEditingController(text: tx.nfseNumber),
                    readOnly: true,
                    suffixIcon: Icons.copy,
                    onSuffixPressed: () => _copy(context, tx.nfseNumber!),
                  ),
                if (tx.accessKey != null) ...[
                  const SizedBox(height: 8),
                  SetesTextField(
                    label: 'forms.serviceOrder.fiscalAccessKey'.tr(),
                    controller: TextEditingController(text: tx.accessKey),
                    readOnly: true,
                    suffixIcon: Icons.copy,
                    onSuffixPressed: () => _copy(context, tx.accessKey!),
                  ),
                ],
              ],
              // D-F139: a 2ª fonte — o EFEITO na nota (ERP). Indisponível é
              // dito como tal, nunca "nada pendente" (D-F79)
              if (state.effectFailure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SetesText(
                    'forms.serviceOrder.fiscalEffectUnavailable'
                        .tr(args: [state.effectFailure!.message.tr()]),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                )
              else if (effectRow != null)
                effectRow,
              // D-F67: NFS-e SUBSTITUÍDA no fisco (e105102, feito no portal)
              if (view != null && view.substitution != null)
                ..._buildSubstitution(context, view.substitution!),
              if (fx != null && fx.cancelWaiver != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SetesText('forms.serviceOrder.fiscalKeptRow'.tr(args: [
                    fiscalDateTimeToDisplay(fx.cancelWaiver!.createdAt),
                    fx.cancelWaiver!.reason,
                  ])),
                ),
              if (view != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Transmitir: pelo ESTADO do servidor (nunca transmitida ou
                    // última tentativa R/F); nota cancelada é documento encerrado
                    if (view.canTransmitState &&
                        !order.isCancelled &&
                        CurrentInterface.can('TRANSMITIR'))
                      SetesButton(
                        label: 'forms.serviceOrder.fiscalTransmit'.tr(),
                        icon: Icons.cloud_upload_outlined,
                        loading: busy,
                        onPressed: busy ? null : onTransmit,
                      ),
                    if (view.currentAttempt != null)
                      SetesButton(
                        label: 'forms.serviceOrder.fiscalRefresh'.tr(),
                        icon: Icons.sync,
                        kind: SetesButtonKind.secondary,
                        loading: busy,
                        onPressed: busy ? null : onFiscalRefresh,
                      ),
                    if (view.xmlAvailable)
                      SetesButton(
                        label: 'forms.serviceOrder.fiscalXml'.tr(),
                        icon: Icons.code,
                        kind: SetesButtonKind.secondary,
                        loading: busy,
                        onPressed: busy ? null : onFiscalXml,
                      ),
                    if (view.danfseAvailable)
                      SetesButton(
                        label: 'forms.serviceOrder.fiscalDanfse'.tr(),
                        icon: Icons.picture_as_pdf_outlined,
                        kind: SetesButtonKind.secondary,
                        loading: busy,
                        onPressed: busy ? null : onFiscalDanfse,
                      ),
                    // Cancelar NFS-e: atalho do MESMO fluxo pelo plano (D-F140)
                    if (view.state == NfseState.authorized && !order.isCancelled && canCancel)
                      SetesButton(
                        label: 'forms.serviceOrder.fiscalCancel'.tr(),
                        icon: Icons.cancel_outlined,
                        kind: SetesButtonKind.secondary,
                        loading: busy,
                        onPressed: busy ? null : onCancelInvoice,
                      ),
                    // D-F140: o fisco cancelou e a nota não — o humano APLICA
                    // (pelo plano; nunca automático)
                    if (fx?.effect == FiscalEffect.apply && !order.isCancelled && canCancel)
                      SetesButton(
                        label: 'forms.serviceOrder.fiscalApplyLocalCancel'.tr(),
                        icon: Icons.playlist_add_check,
                        loading: busy,
                        onPressed: busy ? null : onCancelInvoice,
                      ),
                    // D-F82/D-F80: de ofício (ou substituição em homologação) —
                    // o caminho é cancelar a nota
                    if (fx?.effect == FiscalEffect.cancel && !order.isCancelled && canCancel)
                      SetesButton(
                        label: 'forms.serviceOrder.cancelInvoice'.tr(),
                        icon: Icons.cancel_outlined,
                        loading: busy,
                        onPressed: busy ? null : onCancelInvoice,
                      ),
                    // D-F67: decisão humana de MANTER a nota substituída — a
                    // outra decisão é o "Cancelar nota" (AppBar)
                    if (_substitutionUndecided && canCancel)
                      SetesButton(
                        label: 'forms.serviceOrder.fiscalKeep'.tr(),
                        icon: Icons.task_alt,
                        kind: SetesButtonKind.secondary,
                        loading: busy,
                        onPressed: busy ? null : onKeepInvoice,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (view != null && view.events.isNotEmpty) ...[
          const SizedBox(height: 16),
          SetesText.title('forms.serviceOrder.fiscalEvents'.tr()),
          const SizedBox(height: 8),
          for (final e in view.events) ...[
            _buildFiscalEventTile(e),
            const Divider(height: 1),
          ],
        ],
      ],
    );
  }

  /// Linha do tempo "Voz do fisco": nº, kind (RÓTULO), tentativa, origem P/Q,
  /// código do fisco e mensagem.
  Widget _buildFiscalEventTile(ServiceOrderFiscalEvent e) {
    final cells = [
      'forms.serviceOrder.fiscalAttemptShort'.tr(args: ['${e.attempt}']),
      if (e.dh != null) fiscalDateTimeToDisplay(e.dh),
      fiscalSourceLabel(e.source),
      if (e.authorityCode != null && e.authorityCode!.isNotEmpty)
        e.authorityCode!,
      if (e.message != null && e.message!.isNotEmpty) e.message!,
    ].where((c) => c.isNotEmpty);
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${e.event}')),
      title: SetesText(fiscalKindLabel(e.kind)),
      subtitle: SetesText(cells.join(' · ')),
    );
  }
}
