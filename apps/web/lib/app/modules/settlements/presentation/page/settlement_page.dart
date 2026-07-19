import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/format/money.dart';
import '../../data/datasource/settlement_datasource.dart';
import '../../domain/entity/settlement_entity.dart';
import '../bloc/settlement_bloc.dart';

/// Tela de Baixa de Títulos — interface 'settlements', grupo Financeiro
/// (Módulo Software House, Onda 5). 2ª TELA DE PROCESSO do produto, em
/// 3 ABAS: Em aberto (carteira com seleção MÚLTIPLA e baixa em LOTE —
/// N títulos → 1 código → 1 movimento), Baixados (linha por evento, com
/// estorno IMUTÁVEL mediante motivo) e Movimento (extrato banco/caixa com
/// totais prontos da API — o app nunca soma).
class SettlementPage extends StatefulWidget {
  const SettlementPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título da tela.
  final String title;

  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

/// ISO de hoje ('yyyy-MM-dd') — destaque de vencidos e default de datas.
String _todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// Rótulo da conta: Caixa fixo (id 0) ou '341 - Itaú · Ag 1234 · CC 98765'.
String _accountLabel(SettlementBankAccountLookup account) {
  if (account.id == 0) return 'forms.settlement.cash'.tr();
  final numbers = 'forms.settlement.accountRow'
      .tr(args: [account.agencyText, account.numberText]);
  return account.bankLabel.isEmpty
      ? numbers
      : '${account.bankLabel} · $numbers';
}

/// Kind do título: código cru + descrição i18n curta ('RA · Recebimento
/// automático'); códigos fora do catálogo exibem só o cru.
String _kindLabel(String? kind) {
  if (kind == null || kind.isEmpty) return '';
  const known = ['RA', 'RM', 'PA', 'PM'];
  if (!known.contains(kind)) return kind;
  return '$kind · ${'forms.settlement.kind$kind'.tr()}';
}

/// Lookup de conta com a opção CAIXA (id 0) FIXA na frente da lista.
Future<SettlementBankAccountLookup?> _pickAccount(
    BuildContext context, SettlementDatasource datasource) {
  List<SettlementBankAccountLookup>? cache;
  return showSetesLookup<SettlementBankAccountLookup>(
    context: context,
    title: 'lookup.bankAccounts'.tr(),
    filterHint: 'register.filterHint'.tr(),
    emptyText: 'register.emptyList'.tr(),
    onSearch: (filter) async {
      cache ??= await datasource.bankAccounts();
      final lower = filter.toLowerCase();
      return [
        const SettlementBankAccountLookup(id: 0),
        for (final account in cache!)
          if (lower.isEmpty ||
              _accountLabel(account).toLowerCase().contains(lower))
            account,
      ];
    },
    itemId: (account) => account.id,
    itemLabel: _accountLabel,
  );
}

/// Valor decimal digitado ('1234,56' ou '1234.56') → double.
double? _parseDecimal(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

String _decimalText(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

double _round2(double value) => (value * 100).roundToDouble() / 100;

/// Checagem de UM campo de dialog de ação: [validate] devolve a chave i18n
/// (ou texto pronto) da pendência; [focusNode]/[fieldKey] ancoram o retorno
/// do foco e a marca inline SÓ nele.
class _DialogCheck {
  const _DialogCheck({required this.validate, this.focusNode, this.fieldKey});

  final String? Function() validate;
  final FocusNode? focusNode;
  final GlobalKey<FormFieldState<String>>? fieldKey;
}

/// R3 — UMA pendência por vez nos dialogs de ação (mesma mecânica da
/// fábrica register_form_page): percorre as checagens NA ORDEM declarada
/// e, na PRIMEIRA mensagem, mostra o dialog da ponte → OK → marca SÓ o
/// campo pendente e devolve o foco a ele. true = tudo passou.
Future<bool> _firstPendingCheck(
    BuildContext context, List<_DialogCheck> checks) async {
  for (final check in checks) {
    final message = check.validate();
    if (message != null) {
      // .tr() em texto já traduzido devolve o próprio texto.
      await showValidationFeedback(context, message.tr());
      if (context.mounted) {
        check.fieldKey?.currentState?.validate();
        check.focusNode?.requestFocus();
      }
      return false;
    }
  }
  return true;
}

class _SettlementPageState extends State<SettlementPage>
    with SingleTickerProviderStateMixin {
  late final SettlementBloc _bloc;
  late final SettlementDatasource _datasource;
  late final TabController _tabs;
  final _filter = TextEditingController();

  /// Seleção múltipla da aba Em aberto (chaves orderId-parcel).
  final Set<String> _selected = {};

  /// Filtros da aba Movimento (a página guarda a exibição; o bloc, o
  /// valor vigente). null = Caixa (id 0, default).
  SettlementBankAccountLookup? _stAccount;
  final _stFrom = TextEditingController();
  final _stTo = TextEditingController();
  final _stFromFocus = FocusNode();
  final _stToFocus = FocusNode();
  final _stFromKey = GlobalKey<FormFieldState<String>>();
  final _stToKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<SettlementBloc>()
      ..add(const SettlementBillsRequested(filter: ''));
    _datasource = Modular.get<SettlementDatasource>();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      _loadTab(_tabs.index);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _filter.dispose();
    _stFrom.dispose();
    _stTo.dispose();
    _stFromFocus.dispose();
    _stToFocus.dispose();
    super.dispose();
  }

  void _loadTab(int index) {
    switch (index) {
      case 0:
        _bloc.add(SettlementBillsRequested(filter: _filter.text.trim()));
      case 1:
        _bloc.add(SettlementSettledRequested(filter: _filter.text.trim()));
      case 2:
        _searchStatements();
    }
  }

  /// Engrenagem padrão da lista (Framework de Configurações, decisão 11) —
  /// replicada manualmente porque a tela de processo não usa a fábrica.
  void _openConfigs() {
    Modular.to.navigate('/home/interface-configs/', arguments: {
      'title': trCatalog('interface-configs', 'Interface Configs',
          prefix: 'menu.interfaces'),
      'moduleKey': 'settlements',
      'returnTo': Modular.to.path,
    });
  }

  void _searchList() {
    if (_tabs.index == 0) {
      _bloc.add(SettlementBillsRequested(filter: _filter.text.trim()));
    } else {
      _bloc.add(SettlementSettledRequested(filter: _filter.text.trim()));
    }
  }

  // -------------------------------------------------------------------
  // Aba 1 — Em aberto (seleção múltipla + dialog de baixa)
  // -------------------------------------------------------------------

  Future<void> _openSettleDialog(List<SettlementBill> selectedBills) async {
    final input = await showDialog<SettlementBatchInput>(
      context: context,
      builder: (_) =>
          _SettleDialog(bills: selectedBills, datasource: _datasource),
    );
    if (input != null) {
      setState(() => _selected.clear());
      _bloc.add(SettlementSettleRequested(input));
    }
  }

  Widget _buildBillTile(SettlementBill bill, String todayIso) {
    final theme = Theme.of(context);
    final overdue = bill.isOverdue(todayIso);
    final cells = [
      if (bill.number != null && bill.number!.isNotEmpty)
        'forms.settlement.numberRow'.tr(args: [bill.number!]),
      _kindLabel(bill.kind),
      'forms.settlement.expirationRow'
          .tr(args: [isoDateToDisplay(bill.dtExpiration)]),
      'forms.settlement.valueRow'.tr(args: [setesMoney(bill.tagValue)]),
      'forms.settlement.balanceRow'.tr(args: [setesMoney(bill.balance)]),
      if (overdue) 'forms.settlement.overdue'.tr(),
    ].where((cell) => cell.isNotEmpty);
    return SetesListTile(
      leading: Checkbox(
        value: _selected.contains(bill.key),
        onChanged: (_) => _toggle(bill.key),
      ),
      title: SetesText(bill.entityName ?? ''),
      subtitle: SetesText(
        cells.join(' · '),
        // Vencido: destaque discreto com a cor de erro do tema.
        style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      onTap: () => _toggle(bill.key),
    );
  }

  void _toggle(String key) => setState(() {
        if (!_selected.remove(key)) _selected.add(key);
      });

  Widget _buildBills(SettlementBillsState state) {
    if (state.loading) return const SetesCircularProgressIndicator();
    // Poda chaves que saíram da carteira (baixa total some da aba).
    final validKeys = {for (final bill in state.items) bill.key};
    _selected.removeWhere((key) => !validKeys.contains(key));
    final selectedBills =
        [for (final bill in state.items) if (_selected.contains(bill.key)) bill];
    final total =
        selectedBills.fold<double>(0, (sum, bill) => sum + bill.balance);
    final todayIso = _todayIso();
    return Column(
      children: [
        Expanded(
          child: state.items.isEmpty
              ? Center(child: SetesText('register.emptyList'.tr()))
              : ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildBillTile(state.items[index], todayIso),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: SetesText('forms.settlement.selectedSummary'.tr(
                    args: ['${selectedBills.length}', setesMoney(total)])),
              ),
              SetesButton(
                label: 'forms.settlement.settleSelected'.tr(),
                icon: Icons.check,
                onPressed: selectedBills.isEmpty
                    ? null
                    : () => _openSettleDialog(selectedBills),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Aba 2 — Baixados (selo de status + estorno com motivo)
  // -------------------------------------------------------------------

  Future<void> _openReversalDialog(SettlementSettled settled) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReversalDialog(),
    );
    if (reason != null) {
      _bloc.add(SettlementReversalRequested(
        orderId: settled.orderId,
        parcel:  settled.parcel,
        event:   settled.event,
        reason:  reason,
      ));
    }
  }

  Widget _statusBadge(String status) {
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (status) {
      'E' => (
          'forms.settlement.statusReversed'.tr(),
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      'R' => (
          'forms.settlement.statusReversal'.tr(),
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      _ => (
          'forms.settlement.statusCurrent'.tr(),
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SetesText(label, style: TextStyle(color: foreground, fontSize: 12)),
    );
  }

  Widget _buildSettledTile(SettlementSettled settled) {
    final cells = [
      if (settled.number != null && settled.number!.isNotEmpty)
        'forms.settlement.numberRow'.tr(args: [settled.number!]),
      _kindLabel(settled.kind),
      'forms.settlement.paidRow'.tr(args: [setesMoney(settled.paidValue)]),
      'forms.settlement.dtPaymentRow'
          .tr(args: [isoDateToDisplay(settled.dtPayment)]),
      if (settled.dtRealPayment != null && settled.dtRealPayment!.isNotEmpty)
        'forms.settlement.dtRealPaymentRow'
            .tr(args: [isoDateToDisplay(settled.dtRealPayment)]),
      if (settled.settledCode != null)
        'forms.settlement.settledCodeRow'.tr(args: ['${settled.settledCode}']),
    ].where((cell) => cell.isNotEmpty).toList();
    // Estorno ('R') carrega origem e motivo; estornada ('E') só o selo.
    final detail = [
      if (settled.originEvent != null)
        'forms.settlement.originEventRow'.tr(args: ['${settled.originEvent}']),
      if (settled.reversalReason != null && settled.reversalReason!.isNotEmpty)
        'forms.settlement.reversalReasonRow'
            .tr(args: [settled.reversalReason!]),
    ].join(' · ');
    return SetesListTile(
      title: SetesText(settled.entityName ?? ''),
      subtitle: SetesText(
          detail.isEmpty ? cells.join(' · ') : '${cells.join(' · ')}\n$detail'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusBadge(settled.status),
          if (settled.isCurrent)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'forms.settlement.reverse'.tr(),
              onPressed: () => _openReversalDialog(settled),
            ),
        ],
      ),
    );
  }

  Widget _buildSettled(SettlementSettledState state) {
    if (state.loading) return const SetesCircularProgressIndicator();
    if (state.items.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildSettledTile(state.items[index]),
    );
  }

  // -------------------------------------------------------------------
  // Aba 3 — Movimento (filtro conta/período + totais da API)
  // -------------------------------------------------------------------

  /// Datas do filtro validadas via ponte — R3: UMA pendência por vez com
  /// foco no campo (validateOptionalDate já devolve texto traduzido).
  Future<void> _searchStatements() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => validateOptionalDate(_stFrom.text),
        focusNode: _stFromFocus,
        fieldKey: _stFromKey,
      ),
      _DialogCheck(
        validate: () => validateOptionalDate(_stTo.text),
        focusNode: _stToFocus,
        fieldKey: _stToKey,
      ),
    ]);
    if (!ok || !mounted) return;
    _bloc.add(SettlementStatementsRequested(
      bankAccountId: _stAccount?.id ?? 0,
      dtFrom: displayDateToIso(_stFrom.text) ?? '',
      dtTo:   displayDateToIso(_stTo.text) ?? '',
    ));
  }

  Future<void> _pickStatementAccount() async {
    final picked = await _pickAccount(context, _datasource);
    if (picked != null) {
      setState(() => _stAccount = picked.id == 0 ? null : picked);
      _searchStatements();
    }
  }

  Widget _buildStatementTile(SettlementStatementRow row) {
    final cells = [
      isoDateToDisplay(row.dtRecord),
      if (row.creditValue > 0)
        'forms.settlement.creditRow'.tr(args: [setesMoney(row.creditValue)]),
      if (row.debitValue > 0)
        'forms.settlement.debitRow'.tr(args: [setesMoney(row.debitValue)]),
      if (row.settledCode != null)
        'forms.settlement.settledCodeRow'.tr(args: ['${row.settledCode}']),
    ].where((cell) => cell.isNotEmpty);
    return SetesListTile(
      title: SetesText(row.manualHistory ?? ''),
      subtitle: SetesText(cells.join(' · ')),
      // Selo DISCRETO só nos lançamentos de estorno (E/R) — vigente limpo.
      trailing: row.status == 'N' ? null : _statusBadge(row.status),
    );
  }

  Widget _buildStatements(SettlementStatementsState state) {
    final theme = Theme.of(context);
    final report = state.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: SetesLookupField(
                label: 'forms.settlement.statementAccount'.tr(),
                display: _stAccount == null
                    ? 'forms.settlement.cash'.tr()
                    : _accountLabel(_stAccount!),
                onSearch: _pickStatementAccount,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SetesTextField(
                label: 'forms.settlement.dtFrom'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _stFrom,
                focusNode: _stFromFocus,
                fieldKey: _stFromKey,
                validator: validateOptionalDate,
                onSubmitted: (_) => _searchStatements(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SetesTextField(
                label: 'forms.settlement.dtTo'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _stTo,
                focusNode: _stToFocus,
                fieldKey: _stToKey,
                validator: validateOptionalDate,
                suffixIcon: Icons.search,
                onSuffixPressed: _searchStatements,
                onSubmitted: (_) => _searchStatements(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: state.loading
              ? const SetesCircularProgressIndicator()
              : report.rows.isEmpty
                  ? Center(child: SetesText('register.emptyList'.tr()))
                  : ListView.separated(
                      itemCount: report.rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _buildStatementTile(report.rows[index]),
                    ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(
                child: SetesText('forms.settlement.totalCredits'
                    .tr(args: [setesMoney(report.totalCredit)])),
              ),
              Expanded(
                child: SetesText('forms.settlement.totalDebits'
                    .tr(args: [setesMoney(report.totalDebit)])),
              ),
              // SALDO do filtro — vem pronto da API (o app não soma).
              SetesText(
                'forms.settlement.balanceTotal'
                    .tr(args: [setesMoney(report.balance)]),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Casca (AppBar + abas)
  // -------------------------------------------------------------------

  Widget _buildBody(SettlementState state) => switch (state) {
        SettlementBillsState() => _buildBills(state),
        SettlementSettledState() => _buildSettled(state),
        SettlementStatementsState() => _buildStatements(state),
        _ => const SetesCircularProgressIndicator(),
      };

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SettlementBloc, SettlementState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is SettlementActionSuccess ||
            current is SettlementActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog para desfecho — sucesso = SnackBar
        // via ponte (R1); falha = dialog (o 409 "baixa não vigente" vira
        // validação com a mensagem da API); 400 com fields[] mostra a
        // message do campo apontado (o dialog de ação já fechou — sem
        // campo montado para focar).
        listener: (context, state) {
          if (state is SettlementActionSuccess) {
            showSuccessFeedback(context, state.messageKey,
                args: state.args.isEmpty ? null : state.args);
            return;
          }
          final failure = (state as SettlementActionFailure).failure;
          if (failure.fields.isNotEmpty) {
            showValidationFeedback(context, failure.fields.first.message.tr());
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is SettlementBillsState ||
            current is SettlementSettledState ||
            current is SettlementStatementsState,
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('register.listTitle'.tr(args: [widget.title])),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'register.configTooltip'.tr(),
                onPressed: _openConfigs,
              ),
            ],
          ),
          body: Column(
            children: [
              // Abas no CORPO (padrão service_orders — no bottom da AppBar
              // as cores do tema somem no fundo primário).
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: 'forms.settlement.tabOpen'.tr()),
                  Tab(text: 'forms.settlement.tabSettled'.tr()),
                  Tab(text: 'forms.settlement.tabStatements'.tr()),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filtro de entidade/nº só nas abas de títulos —
                      // o Movimento tem filtro próprio (conta/período).
                      if (_tabs.index != 2) ...[
                        SetesTextField(
                          label: 'register.filter'.tr(),
                          hint: 'register.filterHint'.tr(),
                          controller: _filter,
                          suffixIcon: Icons.search,
                          onSuffixPressed: _searchList,
                          onSubmitted: (_) => _searchList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(child: _buildBody(state)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Controladores de UM título dentro do dialog de baixa — juros, multa,
/// desconto % e valor pago (default = líquido; editar juros/multa/desconto
/// RECALCULA o pago; o usuário pode reduzir para baixa PARCIAL).
class _TitleFields {
  _TitleFields(this.bill)
      : interest = TextEditingController(),
        late = TextEditingController(),
        discount = TextEditingController(),
        paid = TextEditingController(text: _decimalText(bill.balance));

  final SettlementBill bill;
  final TextEditingController interest;
  final TextEditingController late;
  final TextEditingController discount;
  final TextEditingController paid;

  /// Âncoras do R3 (foco + marca inline SÓ no campo pendente).
  final interestFocus = FocusNode();
  final lateFocus = FocusNode();
  final discountFocus = FocusNode();
  final paidFocus = FocusNode();
  final interestKey = GlobalKey<FormFieldState<String>>();
  final lateKey = GlobalKey<FormFieldState<String>>();
  final discountKey = GlobalKey<FormFieldState<String>>();
  final paidKey = GlobalKey<FormFieldState<String>>();

  double get interestValue => _parseDecimal(interest.text) ?? 0;
  double get lateValue => _parseDecimal(late.text) ?? 0;
  double get discountAliquot => _parseDecimal(discount.text) ?? 0;
  double? get paidValue => _parseDecimal(paid.text);

  /// Líquido sugerido: saldo + juros + multa − desconto% sobre o TAG.
  double get liquid => _round2(bill.balance +
      interestValue +
      lateValue -
      _round2(bill.tagValue * discountAliquot / 100));

  /// Juros/multa opcionais — válidos SE preenchidos (>= 0).
  String? validateInterest() => _validateOptionalMin(interest.text,
      'forms.settlement.interestInvalid');

  String? validateLate() =>
      _validateOptionalMin(late.text, 'forms.settlement.lateInvalid');

  /// Desconto opcional — SE preenchido, percentual entre 0 e 100.
  String? validateDiscount() {
    if (discount.text.trim().isEmpty) return null;
    final value = _parseDecimal(discount.text);
    return (value == null || value < 0 || value > 100)
        ? 'forms.settlement.discountInvalid'
        : null;
  }

  /// Valor pago é OBRIGATÓRIO e maior que zero (baixa parcial permitida).
  String? validatePaid() {
    final value = _parseDecimal(paid.text);
    return (value == null || value <= 0)
        ? 'forms.settlement.paidInvalid'
        : null;
  }

  static String? _validateOptionalMin(String text, String messageKey) {
    if (text.trim().isEmpty) return null;
    final value = _parseDecimal(text);
    return (value == null || value < 0) ? messageKey : null;
  }

  void dispose() {
    interest.dispose();
    late.dispose();
    discount.dispose();
    paid.dispose();
    interestFocus.dispose();
    lateFocus.dispose();
    discountFocus.dispose();
    paidFocus.dispose();
  }
}

/// Dialog da BAIXA EM LOTE: apuração por título (juros/multa/desconto/pago
/// — valores INFORMADOS, P5) + campos do lote (conta com Caixa fixo, data
/// da baixa default hoje, compensação opcional) + total ao vivo. Devolve o
/// [SettlementBatchInput] via Navigator.pop.
class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.bills, required this.datasource});

  final List<SettlementBill> bills;
  final SettlementDatasource datasource;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final List<_TitleFields> _titles;
  late final TextEditingController _dtPayment;
  final _dtRealPayment = TextEditingController();
  final _dtPaymentFocus = FocusNode();
  final _dtRealPaymentFocus = FocusNode();
  final _dtPaymentKey = GlobalKey<FormFieldState<String>>();
  final _dtRealPaymentKey = GlobalKey<FormFieldState<String>>();

  /// null = Caixa (id 0) — a opção fixa é o default do lote.
  SettlementBankAccountLookup? _account;

  @override
  void initState() {
    super.initState();
    _titles = [for (final bill in widget.bills) _TitleFields(bill)];
    _dtPayment = TextEditingController(text: isoDateToDisplay(_todayIso()));
  }

  @override
  void dispose() {
    for (final title in _titles) {
      title.dispose();
    }
    _dtPayment.dispose();
    _dtRealPayment.dispose();
    _dtPaymentFocus.dispose();
    _dtRealPaymentFocus.dispose();
    super.dispose();
  }

  /// Total do lote ao vivo — soma dos valores pagos digitados.
  double get _total =>
      _titles.fold<double>(0, (sum, title) => sum + (title.paidValue ?? 0));

  /// Juros/multa/desconto editados → recalcula o pago (o usuário ainda
  /// pode reduzi-lo depois para baixa parcial).
  void _recalc(_TitleFields title) =>
      setState(() => title.paid.text = _decimalText(title.liquid));

  Future<void> _pickBatchAccount() async {
    final picked = await _pickAccount(context, widget.datasource);
    if (picked != null) {
      setState(() => _account = picked.id == 0 ? null : picked);
    }
  }

  /// Data da baixa é OBRIGATÓRIA (vazio = inválida).
  String? _validateDtPayment(String? value) =>
      displayDateToIso(value ?? '') == null ? 'register.invalidDate' : null;

  /// Valida via ponte — R3: UMA pendência por vez, na ORDEM dos campos
  /// (título a título na ordem da lista, depois os campos do lote), com
  /// foco no pendente. Tudo válido → devolve o [SettlementBatchInput].
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      for (final title in _titles) ...[
        _DialogCheck(
          validate: title.validateInterest,
          focusNode: title.interestFocus,
          fieldKey: title.interestKey,
        ),
        _DialogCheck(
          validate: title.validateLate,
          focusNode: title.lateFocus,
          fieldKey: title.lateKey,
        ),
        _DialogCheck(
          validate: title.validateDiscount,
          focusNode: title.discountFocus,
          fieldKey: title.discountKey,
        ),
        _DialogCheck(
          validate: title.validatePaid,
          focusNode: title.paidFocus,
          fieldKey: title.paidKey,
        ),
      ],
      _DialogCheck(
        validate: () => _validateDtPayment(_dtPayment.text),
        focusNode: _dtPaymentFocus,
        fieldKey: _dtPaymentKey,
      ),
      _DialogCheck(
        // Compensação é opcional — válida SE preenchida (texto traduzido).
        validate: () => validateOptionalDate(_dtRealPayment.text),
        focusNode: _dtRealPaymentFocus,
        fieldKey: _dtRealPaymentKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(SettlementBatchInput(
      titles: [
        for (final title in _titles)
          SettlementTitleInput(
            orderId:         title.bill.orderId,
            parcel:          title.bill.parcel,
            interestValue:   title.interestValue,
            lateValue:       title.lateValue,
            discountAliquot: title.discountAliquot,
            paidValue:       title.paidValue!,
          ),
      ],
      bankAccountId: _account?.id ?? 0,
      dtPayment:     displayDateToIso(_dtPayment.text)!,
      dtRealPayment: _dtRealPayment.text.trim().isEmpty
          ? null
          : displayDateToIso(_dtRealPayment.text),
    ));
  }

  Widget _buildTitleCard(_TitleFields title) {
    final bill = title.bill;
    final header = [
      bill.entityName ?? '',
      if (bill.number != null && bill.number!.isNotEmpty)
        'forms.settlement.numberRow'.tr(args: [bill.number!]),
      'forms.settlement.balanceRow'.tr(args: [setesMoney(bill.balance)]),
    ].where((cell) => cell.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetesText(header,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SetesTextField(
                  label: 'forms.settlement.interest'.tr(),
                  controller: title.interest,
                  focusNode: title.interestFocus,
                  fieldKey: title.interestKey,
                  keyboardType: TextInputType.number,
                  validator: (_) => title.validateInterest()?.tr(),
                  onChanged: (_) => _recalc(title),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SetesTextField(
                  label: 'forms.settlement.late'.tr(),
                  controller: title.late,
                  focusNode: title.lateFocus,
                  fieldKey: title.lateKey,
                  keyboardType: TextInputType.number,
                  validator: (_) => title.validateLate()?.tr(),
                  onChanged: (_) => _recalc(title),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SetesTextField(
                  label: 'forms.settlement.discountAliquot'.tr(),
                  controller: title.discount,
                  focusNode: title.discountFocus,
                  fieldKey: title.discountKey,
                  keyboardType: TextInputType.number,
                  validator: (_) => title.validateDiscount()?.tr(),
                  onChanged: (_) => _recalc(title),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SetesTextField(
                  label: 'forms.settlement.paidValue'.tr(),
                  controller: title.paid,
                  focusNode: title.paidFocus,
                  fieldKey: title.paidKey,
                  keyboardType: TextInputType.number,
                  validator: (_) => title.validatePaid()?.tr(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: SetesText('forms.settlement.settleSelected'.tr()),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final title in _titles) _buildTitleCard(title),
              const Divider(height: 1),
              const SizedBox(height: 16),
              SetesLookupField(
                label: 'forms.settlement.account'.tr(),
                display: _account == null
                    ? 'forms.settlement.cash'.tr()
                    : _accountLabel(_account!),
                onSearch: _pickBatchAccount,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SetesTextField(
                      label: 'forms.settlement.dtPayment'.tr(),
                      hint: 'register.dateHint'.tr(),
                      controller: _dtPayment,
                      focusNode: _dtPaymentFocus,
                      fieldKey: _dtPaymentKey,
                      validator: (value) => _validateDtPayment(value)?.tr(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SetesTextField(
                      label: 'forms.settlement.dtRealPayment'.tr(),
                      hint: 'register.dateHint'.tr(),
                      controller: _dtRealPayment,
                      focusNode: _dtRealPaymentFocus,
                      fieldKey: _dtRealPaymentKey,
                      validator: validateOptionalDate,
                      onSubmitted: (_) => _confirm(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Total do LOTE ao vivo (a conferência final é da API).
              SetesText(
                'forms.settlement.batchTotal'.tr(args: [setesMoney(_total)]),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      actions: [
        SetesButton(
          label: 'register.cancel'.tr(),
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SetesButton(
          label: 'forms.settlement.confirmSettle'.tr(),
          kind: SetesButtonKind.text,
          onPressed: _confirm,
        ),
      ],
    );
  }
}

/// Dialog de ESTORNO: confirmação com MOTIVO obrigatório (máx. 100 —
/// gravado no lançamento inverso; financeiro não se apaga). Devolve o
/// motivo via Navigator.pop.
class _ReversalDialog extends StatefulWidget {
  const _ReversalDialog();

  @override
  State<_ReversalDialog> createState() => _ReversalDialogState();
}

class _ReversalDialogState extends State<_ReversalDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();
  final _reasonKey = GlobalKey<FormFieldState<String>>();

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  String? _validateReason(String? value) {
    final reason = value?.trim() ?? '';
    return (reason.isEmpty || reason.length > 100)
        ? 'forms.settlement.reasonRequired'
        : null;
  }

  /// Motivo validado via ponte — R3: dialog de pendência → OK → foco no
  /// campo (o dialog de ENTRADA continua aberto; quem confirma o estorno
  /// é o botão Estornar).
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _validateReason(_reason.text),
        focusNode: _reasonFocus,
        fieldKey: _reasonKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.settlement.reverseTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesText('forms.settlement.reverseConfirm'.tr()),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.settlement.reverseReason'.tr(),
                controller: _reason,
                focusNode: _reasonFocus,
                fieldKey: _reasonKey,
                autofocus: true,
                validator: (value) => _validateReason(value)?.tr(),
                onSubmitted: (_) => _confirm(),
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
            label: 'forms.settlement.reverse'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}
