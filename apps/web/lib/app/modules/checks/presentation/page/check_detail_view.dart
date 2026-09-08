import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/format/money.dart';
import '../../data/datasource/check_lookup_datasource.dart';
import '../../domain/entity/check_entity.dart';
import 'check_action_dialogs.dart';
import 'check_format.dart';

/// Detalhe do cheque DIRIGIDO PELO ESTADO (skill tela-de-processo):
/// cabeçalho imutável (banco, agência/conta, número, emitente, valor, data
/// do cheque, tipo P/T, quem entregou) e linha do tempo de eventos. Ações
/// por ESTADO: EM CUSTÓDIA → Depositar / Descontar / Usar em Pagamento /
/// Devolver; NA FACTORING → Retorno Bom / Retorno com Reembolso. Estornar
/// fica disponível em QUALQUER estado (a API recusa com 409 quando o
/// último evento não é reversível — a tela não pré-bloqueia além do
/// óbvio). Cada ação dispara o callback correspondente, que vira evento do
/// bloc — a API é chamada e o detalhe é RECARREGADO.
class CheckDetailView extends StatelessWidget {
  const CheckDetailView({
    required this.title,
    required this.check,
    required this.saving,
    required this.lookup,
    required this.onBack,
    required this.onDeposit,
    required this.onDiscount,
    required this.onReturnRefund,
    required this.onReturnGood,
    required this.onPay,
    required this.onReturn,
    required this.onReverse,
    super.key,
  });

  final String title;
  final CheckFull check;
  final bool saving;
  final CheckLookupDatasource lookup;
  final VoidCallback onBack;
  final void Function(String dtRecord, int bankAccountId) onDeposit;
  final void Function(CheckDiscountInput input) onDiscount;
  final void Function(String dtRecord, int bankAccountId) onReturnRefund;
  final void Function(String? note) onReturnGood;
  final void Function(CheckPayInput input) onPay;
  final void Function(CheckReturnInput input) onReturn;
  final void Function(int event, String reason) onReverse;

  Future<void> _openDeposit(BuildContext context) async {
    final result = await showCheckDepositDialog(context, check, lookup);
    if (result != null) onDeposit(result.$1, result.$2);
  }

  Future<void> _openDiscount(BuildContext context) async {
    final result = await showCheckDiscountDialog(context, check, lookup);
    if (result != null) onDiscount(result);
  }

  Future<void> _openReturnRefund(BuildContext context) async {
    final result = await showCheckReturnRefundDialog(context, check, lookup);
    if (result != null) onReturnRefund(result.$1, result.$2);
  }

  Future<void> _openReturnGood(BuildContext context) async {
    // null = cancelou o dialog; um CheckReturnGoodResult (mesmo com note
    // null) = confirmou — só aí dispara a ação.
    final result = await showCheckReturnGoodDialog(context, check);
    if (result != null) onReturnGood(result.note);
  }

  Future<void> _openPay(BuildContext context) async {
    final result = await showCheckPayDialog(context, check, lookup);
    if (result != null) onPay(result);
  }

  Future<void> _openReturn(BuildContext context) async {
    final result = await showCheckReturnDialog(context, check);
    if (result != null) onReturn(result);
  }

  Future<void> _openReverse(BuildContext context) async {
    final last = check.events.isEmpty ? null : check.events.last;
    if (last == null) return;
    final reason = await showCheckReverseDialog(context, last);
    if (reason != null) onReverse(last.event, reason);
  }

  Widget _stateBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (check.state) {
      CheckStatus.bank => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      CheckStatus.factoring => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      CheckStatus.supplier => (scheme.primaryContainer, scheme.onPrimaryContainer),
      CheckStatus.refunded => (scheme.errorContainer, scheme.onErrorContainer),
      CheckStatus.collection => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SetesText(checkStatusLabel(check.state),
          style: TextStyle(color: foreground, fontSize: 12)),
    );
  }

  Widget _row(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SetesText(text),
      );

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return SetesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SetesText(
                  check.issuer,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _stateBadge(context),
            ],
          ),
          const SizedBox(height: 8),
          if (check.bankLabel != null && check.bankLabel!.isNotEmpty)
            _row('forms.checks.bankRow'.tr(args: [check.bankLabel!])),
          _row('forms.checks.agencyAccountRow'
              .tr(args: [check.agency, check.account])),
          _row('forms.checks.numberRow'.tr(args: [check.number])),
          _row('forms.checks.dtCheckRow'
              .tr(args: [isoDateToDisplay(check.dtCheck)])),
          _row('forms.checks.headerKindRow'
              .tr(args: [checkHeaderKindLabel(check.headerKind)])),
          if (check.entityName != null && check.entityName!.isNotEmpty)
            _row('forms.checks.entityRow'.tr(args: [check.entityName!])),
          const SizedBox(height: 8),
          SetesText(
            'forms.checks.valueRow'.tr(args: [setesMoney(check.value)]),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Linha do tempo: kind traduzido + data + detalhes do evento (quem,
  /// código da baixa, título ligado, origem do estorno, nota).
  Widget _buildEventTile(CheckEventRow event) {
    final cells = [
      isoDateToDisplay(event.dtRecord),
      if (event.entityName != null && event.entityName!.isNotEmpty)
        event.entityName!,
      if (event.settledCode != null)
        'forms.checks.settledCodeRow'.tr(args: ['${event.settledCode}']),
      if (event.orderId != null)
        'forms.checks.titleRow'
            .tr(args: ['${event.orderId}', '${event.parcel ?? 0}']),
      if (event.originEvent != null)
        'forms.checks.originEventRow'.tr(args: ['${event.originEvent}']),
      if (event.note != null && event.note!.isNotEmpty)
        'forms.checks.noteRow'.tr(args: [event.note!]),
    ].where((cell) => cell.isNotEmpty);
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${event.event}')),
      title: SetesText(checkEventKindLabel(event.kind)),
      subtitle: SetesText(cells.join(' · ')),
    );
  }

  /// Ações da CUSTÓDIA: depositar / descontar / usar em pagamento /
  /// devolver — decisão de UX: 4 botões lado a lado (Wrap), sem hierarquia
  /// forçada entre eles (todos são caminhos igualmente válidos do cheque).
  List<Widget> _custodyActions(BuildContext context) => [
        SetesButton(
          label: 'forms.checks.deposit'.tr(),
          icon: Icons.account_balance,
          loading: saving,
          onPressed: saving ? null : () => _openDeposit(context),
        ),
        SetesButton(
          label: 'forms.checks.discount'.tr(),
          icon: Icons.percent,
          kind: SetesButtonKind.secondary,
          loading: saving,
          onPressed: saving ? null : () => _openDiscount(context),
        ),
        SetesButton(
          label: 'forms.checks.pay'.tr(),
          icon: Icons.payments_outlined,
          kind: SetesButtonKind.secondary,
          loading: saving,
          onPressed: saving ? null : () => _openPay(context),
        ),
        SetesButton(
          label: 'forms.checks.returnToOrigin'.tr(),
          icon: Icons.reply,
          kind: SetesButtonKind.secondary,
          loading: saving,
          onPressed: saving ? null : () => _openReturn(context),
        ),
      ];

  /// Ações da FACTORING: retorno bom (sem movimento) e retorno com
  /// reembolso (sem fundos — dinheiro volta para a factoring).
  List<Widget> _factoringActions(BuildContext context) => [
        SetesButton(
          label: 'forms.checks.returnGood'.tr(),
          icon: Icons.check_circle_outline,
          loading: saving,
          onPressed: saving ? null : () => _openReturnGood(context),
        ),
        SetesButton(
          label: 'forms.checks.returnRefund'.tr(),
          icon: Icons.assignment_return_outlined,
          kind: SetesButtonKind.secondary,
          loading: saving,
          onPressed: saving ? null : () => _openReturnRefund(context),
        ),
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: saving ? null : onBack,
          ),
          title: Text(title),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            SetesText.title('forms.checks.events'.tr()),
            const SizedBox(height: 8),
            for (final event in check.events) ...[
              _buildEventTile(event),
              const Divider(height: 1),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                if (check.isCustody) ..._custodyActions(context),
                if (check.isFactoring) ..._factoringActions(context),
                // Estornar: disponível em QUALQUER estado — a API decide
                // se o último evento é reversível (409 caso não seja).
                SetesButton(
                  label: 'forms.checks.reverse'.tr(),
                  icon: Icons.undo,
                  kind: SetesButtonKind.text,
                  loading: saving,
                  onPressed: saving ? null : () => _openReverse(context),
                ),
              ],
            ),
          ],
        ),
      );
}
