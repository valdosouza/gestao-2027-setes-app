import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/format/money.dart';
import '../../data/datasource/bank_slip_lookup_datasource.dart';
import '../../domain/entity/bank_slip_entity.dart';

/// Dialog EMITIR BOLETO (prompt_boleto_emitido.md D3/D9): (a) carteira de
/// cobrança ativa — lookup /agreements, pré-selecionada quando só há uma;
/// (b) títulos a receber abertos sem boleto vigente — lookup /open-titles
/// com seleção MÚLTIPLA; ao marcar o 1º título a lista passa a mostrar só
/// o MESMO cliente (D9: agrupado só do mesmo cliente); (c) vencimento —
/// 1 título: default = vencimento do título (editável); N títulos:
/// OBRIGATÓRIO; (d) total = soma dos saldos (exibição — a API é a fonte).
/// Validação R3 (uma pendência por vez) via [PendencyField]; devolve o
/// [BankSlipIssueInput] pelo Navigator.pop — quem emite é o bloc.
class BankSlipIssueDialog extends StatefulWidget {
  const BankSlipIssueDialog({required this.lookup, super.key});

  final BankSlipLookupDatasource lookup;

  @override
  State<BankSlipIssueDialog> createState() => _BankSlipIssueDialogState();
}

class _BankSlipIssueDialogState extends State<BankSlipIssueDialog> {
  BankSlipAgreementLookup? _agreement;

  /// Carteiras carregadas uma vez (só 1 → pré-seleção).
  List<BankSlipAgreementLookup>? _agreements;

  final _titleFilter = TextEditingController();
  List<BankSlipOpenTitle> _titles = const [];
  bool _loadingTitles = true;

  /// Seleção múltipla por chave (orderId-parcel) com o título INTEIRO —
  /// sobrevive à troca de filtro (soma e payload não dependem da lista
  /// visível).
  final Map<String, BankSlipOpenTitle> _selected = {};

  final _dtExpiration = TextEditingController();
  final _dtExpirationFocus = FocusNode();
  final _dtExpirationKey = GlobalKey<FormFieldState<String>>();

  /// true depois que o usuário editou o vencimento — a partir daí a tela
  /// não sobrescreve o default do título.
  bool _expirationTouched = false;

  @override
  void initState() {
    super.initState();
    _loadAgreements();
    _loadTitles();
  }

  @override
  void dispose() {
    _titleFilter.dispose();
    _dtExpiration.dispose();
    _dtExpirationFocus.dispose();
    super.dispose();
  }

  /// Cliente da seleção (D9) — null enquanto nada está marcado.
  int? get _customerId =>
      _selected.isEmpty ? null : _selected.values.first.customerId;

  double get _total =>
      _selected.values.fold<double>(0, (sum, t) => sum + t.balance);

  Future<void> _loadAgreements() async {
    try {
      final list = await widget.lookup.agreements();
      if (!mounted) return;
      setState(() {
        _agreements = list;
        // Só 1 carteira ativa → pré-seleciona (o usuário ainda pode trocar).
        if (list.length == 1) _agreement ??= list.first;
      });
    } on Object catch (_) {
      // Falha no lookup: o campo fica vazio e a lista abre vazia — a
      // emissão barra na pendência de carteira (não há o que escolher).
      if (mounted) setState(() => _agreements = const []);
    }
  }

  Future<void> _loadTitles() async {
    setState(() => _loadingTitles = true);
    try {
      final list = await widget.lookup
          .openTitles(_titleFilter.text.trim(), customerId: _customerId);
      if (!mounted) return;
      setState(() {
        _titles = list;
        _loadingTitles = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _titles = const [];
        _loadingTitles = false;
      });
    }
  }

  Future<void> _pickAgreement() async {
    final picked = await showSetesLookup<BankSlipAgreementLookup>(
      context: context,
      title: 'lookup.agreements'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: (filter) async {
        final list = _agreements ?? await widget.lookup.agreements();
        _agreements = list;
        final lower = filter.toLowerCase();
        return [
          for (final a in list)
            if (lower.isEmpty || a.display.toLowerCase().contains(lower)) a,
        ];
      },
      itemId: (a) => a.id,
      itemLabel: (a) => a.display,
    );
    if (picked != null && mounted) setState(() => _agreement = picked);
  }

  /// Marca/desmarca o título; a mudança do cliente da seleção (1º marcado
  /// / último desmarcado) RECARREGA a lista com o filtro de cliente (D9)
  /// e o vencimento default acompanha a regra 1 × N.
  void _toggle(BankSlipOpenTitle title) {
    final before = _customerId;
    setState(() {
      if (_selected.remove(title.key) == null) _selected[title.key] = title;
    });
    _applyExpirationDefault();
    if (_customerId != before) _loadTitles();
  }

  /// 1 título → default = vencimento do título; 0 ou N → limpa (no
  /// agrupado o vencimento é decisão do usuário). Só enquanto o usuário
  /// não editou o campo.
  void _applyExpirationDefault() {
    if (_expirationTouched) return;
    if (_selected.length == 1) {
      _dtExpiration.text =
          isoDateToDisplay(_selected.values.first.dtExpiration);
    } else {
      _dtExpiration.clear();
    }
  }

  String? _validateAgreement() =>
      _agreement == null ? 'forms.bankSlip.agreementRequired' : null;

  String? _validateTitles() =>
      _selected.isEmpty ? 'forms.bankSlip.titlesRequired' : null;

  /// Vencimento: obrigatório no agrupado (N > 1); se preenchido, data
  /// válida. Individual vazio = a API assume o vencimento do título.
  String? _validateExpiration() {
    final text = _dtExpiration.text.trim();
    if (text.isEmpty) {
      return _selected.length > 1
          ? 'forms.bankSlip.expirationRequired'
          : null;
    }
    return displayDateToIso(text) == null ? 'register.invalidDate' : null;
  }

  /// Campos participantes (na ORDEM da tela) — names casam com o payload
  /// (agreementId/titles/dtExpiration) para o fields[] do servidor.
  List<PendencyField> get _pendencyFields => [
        PendencyField(name: 'agreementId', validate: _validateAgreement),
        PendencyField(name: 'titles', validate: _validateTitles),
        PendencyField(
          name: 'dtExpiration',
          validate: _validateExpiration,
          focusNode: _dtExpirationFocus,
          fieldKey: _dtExpirationKey,
        ),
      ];

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, _pendencyFields);
    if (!ok || !mounted) return;
    final iso = displayDateToIso(_dtExpiration.text);
    Navigator.of(context).pop(BankSlipIssueInput(
      agreementId: _agreement!.id,
      titles: [for (final t in _selected.values) t.ref],
      dtExpiration: iso,
    ));
  }

  Widget _buildTitleTile(BankSlipOpenTitle title) {
    final cells = [
      if (title.number != null && title.number!.isNotEmpty)
        'forms.bankSlip.titleNumberRow'.tr(args: [title.number!]),
      'forms.bankSlip.expirationRow'
          .tr(args: [isoDateToDisplay(title.dtExpiration)]),
      'forms.bankSlip.balanceRow'.tr(args: [setesMoney(title.balance)]),
      if (title.paymentTypeDescription != null &&
          title.paymentTypeDescription!.isNotEmpty)
        title.paymentTypeDescription!,
    ].where((cell) => cell.isNotEmpty);
    return SetesListTile(
      leading: Checkbox(
        value: _selected.containsKey(title.key),
        onChanged: (_) => _toggle(title),
      ),
      title: SetesText(title.entityName ?? ''),
      subtitle: SetesText(cells.join(' · ')),
      onTap: () => _toggle(title),
    );
  }

  Widget _buildTitlesBox() {
    if (_loadingTitles) return const SetesCircularProgressIndicator();
    if (_titles.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    return ListView.separated(
      itemCount: _titles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildTitleTile(_titles[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customerName =
        _selected.isEmpty ? null : _selected.values.first.entityName;
    return AlertDialog(
      title: SetesText('forms.bankSlip.issue'.tr()),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesLookupField(
              label: 'forms.bankSlip.agreement'.tr(),
              display: _agreement?.display ?? '',
              onSearch: _pickAgreement,
              onClear: _agreement == null
                  ? null
                  : () => setState(() => _agreement = null),
            ),
            const SizedBox(height: 12),
            SetesTextField(
              label: 'forms.bankSlip.titlesFilter'.tr(),
              hint: 'register.filterHint'.tr(),
              controller: _titleFilter,
              suffixIcon: Icons.search,
              onSuffixPressed: _loadTitles,
              onSubmitted: (_) => _loadTitles(),
            ),
            const SizedBox(height: 8),
            // D9: com título marcado a lista fica restrita ao cliente.
            if (customerName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SetesText(
                  'forms.bankSlip.customerLock'.tr(args: [customerName]),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            SizedBox(
              height: 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildTitlesBox(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SetesTextField(
                    label: 'forms.bankSlip.dtExpiration'.tr(),
                    hint: 'register.dateHint'.tr(),
                    controller: _dtExpiration,
                    focusNode: _dtExpirationFocus,
                    fieldKey: _dtExpirationKey,
                    validator: (_) => _validateExpiration()?.tr(),
                    onChanged: (_) => _expirationTouched = true,
                    onSubmitted: (_) => _confirm(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SetesText(
                    'forms.bankSlip.selectedSummary'
                        .tr(args: ['${_selected.length}', setesMoney(_total)]),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        SetesButton(
          label: 'register.cancel'.tr(),
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SetesButton(
          label: 'forms.bankSlip.confirmIssue'.tr(),
          kind: SetesButtonKind.text,
          onPressed: _confirm,
        ),
      ],
    );
  }
}

/// Abre o dialog de emissão e devolve o input (null = cancelado).
Future<BankSlipIssueInput?> showBankSlipIssueDialog(
        BuildContext context, BankSlipLookupDatasource lookup) =>
    showDialog<BankSlipIssueInput>(
      context: context,
      builder: (_) => BankSlipIssueDialog(lookup: lookup),
    );

/// Feedback do fields[] da emissão quando o dialog JÁ fechou (o bloc
/// executa o POST): ancora pelo name do payload — sem campo montado para
/// focar, a ponte mostra a message do servidor (ex.: vencimento do
/// agrupado).
Future<void> showBankSlipServerFieldFeedback(
        BuildContext context, Failure failure) =>
    showServerFieldFeedback(context, failure, const [
      PendencyField(name: 'agreementId', validate: _none),
      PendencyField(name: 'titles', validate: _none),
      PendencyField(name: 'dtExpiration', validate: _none),
    ]);

String? _none() => null;
