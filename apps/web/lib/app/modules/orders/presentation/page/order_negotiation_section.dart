import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/format/money.dart';
import '../../data/datasource/order_datasource.dart';
import '../../domain/entity/order_entity.dart';
import 'order_format.dart';

/// Seção "Negociação" do detalhe do pedido (prompt_negociacao_pedido.md
/// D3: UMA tela, DUAS vias). Cabeçalho = via SIMPLES (forma de pagamento
/// + prazo string '028/056/084'; vazio = à vista) sobre a BASE DO PEDIDO
/// (itens + frete, sem impostos — D4/D7). Grade = em `simple` mostra o
/// `preview` gerado do prazo (somente leitura) com o botão "Negociar
/// parcelas", que COPIA o preview para uma grade EDITÁVEL (vira ELABORADA
/// só quando o usuário salva — o preview nunca é gravado como elaborado);
/// em `elaborated` a grade já nasce editável. Forma POR PARCELA opcional
/// (D6): vazio = herda a do cabeçalho — o app manda null, NUNCA copia o
/// id do cabeçalho. "Voltar ao prazo" apaga o elaborado (PUT sem
/// installments). Pedido faturado (F) = tudo somente leitura.
///
/// Feedback SÓ pela ponte (Framework de Mensagens): pendência local UMA
/// por vez com foco no campo; `fields[]` do PUT ancorado em
/// deadline / paymentTypeId / installments[.i.campo]
/// ([OrderNegotiationSectionState.showServerFailure]).
///
/// Rodada 2 (2026-09-07): a tela CONSOME `fields[].expected` (D-N3 — a
/// base nova do pedido num INSTALLMENT_MISMATCH e o limite real num
/// MAX_PARCELS_EXCEEDED corrigem a tela com o número, sem parse de prosa)
/// e `deadlineValid`/`deadlineCanonical` (D-N4 — prazo legado do sync
/// tolerado enquanto o texto não muda, com aviso; prazo novo validado
/// localmente pelo espelho do normalizador da API). D-N6: vencimento
/// ANTERIOR a hoje é aceito (negociação legítima — sinal já recebido), mas
/// a tela AVISA: selo na linha, contagem no rodapé e decisão tipada ao
/// salvar — nunca bloqueia.
class OrderNegotiationSection extends StatefulWidget {
  const OrderNegotiationSection({
    required this.negotiation,
    required this.datasource,
    required this.busy,
    required this.onSave,
    required this.onReload,
    this.todayIso,
    super.key,
  });

  /// null = a leitura falhou (a seção oferece "recarregar").
  final OrderNegotiation? negotiation;

  /// Lookups da negociação (formas de pagamento) — só /api/orders.
  final OrderDatasource datasource;

  /// Operação em voo no detalhe — desabilita as ações.
  final bool busy;

  /// PUT /:id/negotiation — quem executa é o bloc (apresentação pura).
  final void Function(OrderNegotiationInput input) onSave;

  /// Recarrega a negociação (leitura que falhou).
  final VoidCallback onReload;

  /// "Hoje" em ISO para as regras de data (vencimento no passado — D-N6;
  /// sugestão de vencimento das linhas novas). null = relógio real;
  /// injetado nos testes para o resultado não depender do dia da execução.
  final String? todayIso;

  @override
  State<OrderNegotiationSection> createState() =>
      OrderNegotiationSectionState();
}

/// Linha EDITÁVEL da grade: controllers de vencimento (dd/mm/aaaa) e
/// valor (2 casas, vírgula) + forma PRÓPRIA opcional (null = herda).
class _ParcelRow {
  _ParcelRow({
    required String dueDateIso,
    required double amount,
    this.paymentTypeId,
    this.paymentTypeDescription,
    this.paymentTypeKind,
  })  : dueDate = TextEditingController(text: isoDateToDisplay(dueDateIso)),
        amount = TextEditingController(
            text: amount == 0 ? '' : orderDecimalText(amount));

  /// Da grade elaborada gravada OU do preview copiado: só a forma PRÓPRIA
  /// vira id na linha (M2 — herdada = null, mesmo vindo resolvida da API).
  factory _ParcelRow.fromParcel(OrderNegotiationParcel parcel) => _ParcelRow(
        dueDateIso: parcel.dueDate,
        amount: parcel.amount,
        paymentTypeId: parcel.ownPaymentType ? parcel.paymentTypeId : null,
        paymentTypeDescription:
            parcel.ownPaymentType ? parcel.paymentTypeDescription : null,
        paymentTypeKind: parcel.ownPaymentType ? parcel.paymentTypeKind : null,
      );

  final TextEditingController dueDate;
  final TextEditingController amount;
  final dueDateFocus = FocusNode();
  final amountFocus = FocusNode();
  final dueDateKey = GlobalKey<FormFieldState<String>>();
  final amountKey = GlobalKey<FormFieldState<String>>();

  int?    paymentTypeId;
  String? paymentTypeDescription;
  String? paymentTypeKind;

  double? get amountValue => orderParseDecimal(amount.text);
  String? get dueDateIso => displayDateToIso(dueDate.text);

  void dispose() {
    dueDate.dispose();
    amount.dispose();
    dueDateFocus.dispose();
    amountFocus.dispose();
  }
}

class OrderNegotiationSectionState extends State<OrderNegotiationSection> {
  // Cabeçalho (via simples).
  int?    _paymentTypeId;
  String  _paymentTypeDescription = '';
  String? _paymentTypeKind;
  int?    _maxParcels;

  /// Prazo COMO GRAVADO no servidor (D-N4): texto igual = aceito de volta
  /// mesmo sendo legado; texto diferente = prazo NOVO, validado localmente.
  String? _deadlineRaw;

  /// Base do pedido apontada pelo servidor num 422 INSTALLMENT_MISMATCH
  /// (`expected`, D-N3): a tela estava com a base velha (itens editados
  /// fora dela) e passa a comparar com a nova até chegar outra negociação.
  double? _baseOverride;

  /// Texto da forma no pedido FATURADO (campo somente leitura).
  final _paymentTypeText = TextEditingController();
  final _deadline = TextEditingController();
  final _deadlineFocus = FocusNode();
  final _deadlineKey = GlobalKey<FormFieldState<String>>();

  /// Grade EDITÁVEL: true quando a negociação gravada é elaborada OU o
  /// usuário clicou "Negociar parcelas" (edição local ainda não salva).
  bool _editing = false;
  final List<_ParcelRow> _rows = [];

  OrderNegotiation? get _negotiation => widget.negotiation;
  bool get _readOnly => !(_negotiation?.isOpen ?? false);
  bool get _busy => widget.busy;
  double get _base => _baseOverride ?? _negotiation?.base.base ?? 0;

  /// Grade elaborada JÁ GRAVADA no servidor (× edição local não salva).
  bool get _savedElaborated => _negotiation?.isElaborated ?? false;

  String get _todayIso => widget.todayIso ?? orderTodayIso();

  /// Achado do passeio logado nº 2: a marca da pendência local ficava no
  /// campo depois de corrigido (o Form só revalida no próximo Salvar).
  /// Revalida SÓ enquanto há erro — some ao ficar válido, sem validar ao
  /// vivo enquanto o usuário digita um valor ainda incompleto.
  void _revalidateIfMarked(GlobalKey<FormFieldState<String>> key) {
    final state = key.currentState;
    if (state != null && state.hasError) state.validate();
  }

  /// D-N6: vencimento ANTERIOR a hoje (ISO compara em texto). Aceito —
  /// a tela só avisa.
  bool _isPastDue(String? iso) => iso != null && iso.compareTo(_todayIso) < 0;

  int get _pastDueCount =>
      _rows.where((row) => _isPastDue(row.dueDateIso)).length;

  @override
  void initState() {
    super.initState();
    _syncFrom(_negotiation);
  }

  /// Negociação nova vinda da API (após salvar, após operação de item —
  /// a base muda) → a seção volta a espelhar o servidor. Re-emits de
  /// saving/falha carregam o MESMO objeto e não passam por aqui (edição
  /// local preservada).
  @override
  void didUpdateWidget(covariant OrderNegotiationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.negotiation != widget.negotiation) _syncFrom(_negotiation);
  }

  @override
  void dispose() {
    _paymentTypeText.dispose();
    _deadline.dispose();
    _deadlineFocus.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    super.dispose();
  }

  /// Tira as linhas da grade; os controllers ainda estão ligados aos
  /// campos montados — o dispose fica para DEPOIS do rebuild que os
  /// desmonta (dispor antes dispara "used after being disposed").
  void _disposeRows() {
    final removed = List<_ParcelRow>.of(_rows);
    _rows.clear();
    if (removed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in removed) {
        row.dispose();
      }
    });
  }

  void _syncFrom(OrderNegotiation? negotiation) {
    _disposeRows();
    final billing = negotiation?.billing;
    _paymentTypeId          = billing?.paymentTypeId;
    _paymentTypeDescription = billing?.paymentTypeDescription ?? '';
    _paymentTypeKind        = billing?.paymentTypeKind;
    _maxParcels             = billing?.maxParcels;
    _paymentTypeText.text   = _paymentTypeDescription;
    _deadline.text          = billing?.deadline ?? '';
    _deadlineRaw            = billing?.deadline;
    _baseOverride           = null;
    _editing = negotiation?.isElaborated ?? false;
    if (_editing) {
      for (final parcel in negotiation!.installments) {
        _rows.add(_ParcelRow.fromParcel(parcel));
      }
    }
    // A marca de pendência local não sobrevive ao texto que veio do
    // servidor (Salvar com sucesso / recarga).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revalidateIfMarked(_deadlineKey);
    });
  }

  // -------------------------------------------------------------------
  // Cálculo local (espelho do servidor — que valida de novo)
  // -------------------------------------------------------------------

  double get _sum =>
      _rows.fold(0.0, (acc, row) => acc + (row.amountValue ?? 0));

  /// Diferença soma × base em CENTAVOS (0 = bate).
  int get _diffCents => orderCents(_sum) - orderCents(_base);

  bool get _sumMatches => _diffCents == 0;

  /// Salvar bloqueado no cliente quando a grade editável não fecha com a
  /// base (mensagem clara no rodapé) — o servidor valida de novo.
  bool get _canSave => !_busy && !_readOnly && (!_editing || _sumMatches);

  // -------------------------------------------------------------------
  // Lookups
  // -------------------------------------------------------------------

  Future<OrderPaymentTypeLookup?> _lookupPaymentType() =>
      showSetesLookup<OrderPaymentTypeLookup>(
        context: context,
        title: 'lookup.paymentTypes'.tr(),
        filterHint: 'register.filterHint'.tr(),
        emptyText: 'register.emptyList'.tr(),
        onSearch: widget.datasource.paymentTypesLookup,
        itemId: (pt) => pt.id,
        itemLabel: (pt) => pt.isCheck
            ? '${pt.description} (${'forms.order.checkKind'.tr()})'
            : pt.description,
      );

  Future<void> _pickPaymentType() async {
    final picked = await _lookupPaymentType();
    if (picked == null || !mounted) return;
    setState(() {
      _paymentTypeId          = picked.id;
      _paymentTypeDescription = picked.description;
      _paymentTypeKind        = picked.kind;
      _maxParcels             = picked.maxParcels;
    });
  }

  Future<void> _pickRowPaymentType(_ParcelRow row) async {
    final picked = await _lookupPaymentType();
    if (picked == null || !mounted) return;
    setState(() {
      row.paymentTypeId          = picked.id;
      row.paymentTypeDescription = picked.description;
      row.paymentTypeKind        = picked.kind;
    });
  }

  /// Limpar a forma da parcela = voltar a HERDAR a do cabeçalho (null).
  void _clearRowPaymentType(_ParcelRow row) => setState(() {
        row.paymentTypeId          = null;
        row.paymentTypeDescription = null;
        row.paymentTypeKind        = null;
      });

  Future<void> _pickDate(TextEditingController controller) async {
    final currentIso = displayDateToIso(controller.text);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          currentIso == null ? DateTime.now() : DateTime.parse(currentIso),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => controller.text = isoDateToDisplay(orderIsoDate(picked)));
  }

  // -------------------------------------------------------------------
  // Grade
  // -------------------------------------------------------------------

  /// "Negociar parcelas": COPIA o preview para a grade editável (sem
  /// preview — sem prazo gravado ainda — nasce 1 parcela com a base,
  /// vencendo hoje). Nada é gravado até o Salvar.
  void _startElaborated() {
    final preview = _negotiation?.preview ?? const [];
    setState(() {
      _disposeRows();
      if (preview.isEmpty) {
        _rows.add(_ParcelRow(dueDateIso: _todayIso, amount: _base));
      } else {
        for (final parcel in preview) {
          _rows.add(_ParcelRow.fromParcel(parcel));
        }
      }
      _editing = true;
    });
  }

  /// Nova linha: vence 30 dias após a última e já sugere o que FALTA para
  /// fechar a base (o usuário ajusta).
  void _addRow() {
    final lastIso = _rows.isEmpty ? null : _rows.last.dueDateIso;
    final dueIso = lastIso == null
        ? _todayIso
        : orderIsoAddDays(lastIso, 30);
    final remaining = (orderCents(_base) - orderCents(_sum)) / 100;
    setState(() => _rows.add(_ParcelRow(
          dueDateIso: dueIso,
          amount: remaining > 0 ? remaining : 0,
        )));
  }

  void _removeRow(int index) {
    final row = _rows[index];
    setState(() => _rows.removeAt(index));
    // Campo ainda montado até o rebuild — dispose adiado (ver _disposeRows).
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  /// "Voltar ao prazo": decisão tipada — Sim apaga o elaborado GRAVADO
  /// (PUT sem installments) ou só descarta a edição local não salva.
  Future<void> _backToDeadline() async {
    final decision = await askDecision(
      context,
      message: 'forms.order.confirmBackToDeadline'.tr(),
      yesLabel: 'forms.order.backToDeadline'.tr(),
    );
    if (decision != SetesDecision.yes || !mounted) return;
    if (_savedElaborated) {
      final paymentTypeId = _paymentTypeId;
      if (paymentTypeId == null) {
        await showValidationFeedback(
            context, 'forms.order.paymentTypeRequired'.tr());
        return;
      }
      widget.onSave(OrderNegotiationInput(
        paymentTypeId: paymentTypeId,
        deadline: _deadline.text,
      ));
      return;
    }
    setState(() {
      _disposeRows();
      _editing = false;
    });
  }

  // -------------------------------------------------------------------
  // Validação (uma pendência por vez) + Salvar
  // -------------------------------------------------------------------

  String? _validateDate(String? value) =>
      displayDateToIso(value ?? '') == null ? 'register.invalidDate' : null;

  String? _validateAmount(String? value) {
    final amount = orderParseDecimal(value ?? '');
    return (amount == null || amount <= 0 || !orderHasTwoDecimals(amount))
        ? 'forms.order.amountInvalid'
        : null;
  }

  /// Espelho do `normalizeDeadline` da API (D-N4): texto IGUAL ao gravado
  /// passa (inclusive o legado tolerado — a API aceita o mesmo raw de
  /// volta); prazo NOVO é estrito — partes numéricas 0..[kMaxDeadlineDays]
  /// separadas por / , ; | -; vazio = à vista. Na via simples o nº de
  /// partes também não pode passar do limite da forma (o servidor conta
  /// as parcelas do prazo; na elaborada conta as linhas da grade).
  String? _validateDeadline(String? value) {
    final text = (value ?? '').trim();
    if (text == (_deadlineRaw ?? '').trim() || text.isEmpty) return null;
    final parts = text.split(RegExp(r'[/,;|-]')).map((p) => p.trim()).toList();
    for (final part in parts) {
      final days = int.tryParse(part);
      if (!RegExp(r'^\d{1,4}$').hasMatch(part) ||
          days == null ||
          days > kMaxDeadlineDays) {
        return 'forms.order.deadlineInvalid';
      }
    }
    final max = _maxParcels;
    if (!_editing && max != null && max > 0 && parts.length > max) {
      return 'forms.order.maxParcelsExceeded'.tr(args: ['$max']);
    }
    return null;
  }

  /// Campos NA ORDEM da tela — a mesma lista serve à pendência local e à
  /// âncora do `fields[]` do servidor (paths `installments.<i>.<campo>`
  /// casam pelo name exato; `installments` seco cai na 1ª linha).
  List<PendencyField> _pendencyFields() => [
        PendencyField(
          name: 'paymentTypeId',
          validate: () => _paymentTypeId == null
              ? 'forms.order.paymentTypeRequired'
              : null,
        ),
        PendencyField(
          name: 'deadline',
          validate: () => _validateDeadline(_deadline.text),
          focusNode: _deadlineFocus,
          fieldKey: _deadlineKey,
        ),
        if (_editing)
          for (var i = 0; i < _rows.length; i++) ...[
            PendencyField(
              name: 'installments.$i.dueDate',
              validate: () => _validateDate(_rows[i].dueDate.text),
              focusNode: _rows[i].dueDateFocus,
              fieldKey: _rows[i].dueDateKey,
            ),
            PendencyField(
              name: 'installments.$i.amount',
              validate: () => _validateAmount(_rows[i].amount.text),
              focusNode: _rows[i].amountFocus,
              fieldKey: _rows[i].amountKey,
            ),
          ],
        // Sempre presente: âncora do `installments` do servidor mesmo fora
        // da edição (ex.: MAX_PARCELS_EXCEEDED apontando a grade gravada).
        PendencyField(
          name: 'installments',
          validate: () => _editing ? _validateGrid() : null,
          focusNode: _rows.isEmpty ? null : _rows.first.amountFocus,
        ),
      ];

  /// Regras da grade inteira (depois das linhas): ao menos 1 parcela,
  /// limite da forma e soma = base (texto pronto com os valores).
  String? _validateGrid() {
    if (_rows.isEmpty) return 'forms.order.parcelsRequired';
    final max = _maxParcels;
    if (max != null && max > 0 && _rows.length > max) {
      return 'forms.order.maxParcelsExceeded'.tr(args: ['$max']);
    }
    if (!_sumMatches) {
      return 'forms.order.sumMismatch'
          .tr(args: [setesMoney(_sum), setesMoney(_base)]);
    }
    return null;
  }

  Future<void> _save() async {
    final ok = await ensureNoPendency(context, _pendencyFields());
    if (!ok || !mounted) return;
    // D-N6: aceita, mas pergunta — Sim grava, Cancelar volta à grade.
    if (_editing && _pastDueCount > 0) {
      final decision = await askDecision(
        context,
        message: 'forms.order.confirmPastDueDates'
            .tr(args: ['$_pastDueCount']),
        yesLabel: 'forms.order.saveAnyway'.tr(),
      );
      if (decision != SetesDecision.yes || !mounted) return;
    }
    widget.onSave(OrderNegotiationInput(
      paymentTypeId: _paymentTypeId!,
      deadline: _deadline.text,
      // Grade editável = via ELABORADA (a grade gravada volta INTEIRA
      // mesmo quando só forma/prazo mudaram — sem isso a API entende
      // "voltar ao prazo"); sem edição = via SIMPLES (null).
      installments: _editing
          ? [
              for (var i = 0; i < _rows.length; i++)
                OrderInstallmentInput(
                  parcel:        i + 1,
                  dueDate:       _rows[i].dueDateIso!,
                  amount:        _rows[i].amountValue!,
                  paymentTypeId: _rows[i].paymentTypeId,
                ),
            ]
          : null,
    ));
  }

  /// `fields[]` do PUT (ou do faturamento, via página) ancorado no campo
  /// (deadline / paymentTypeId / installments[.i.campo]); sem fields[] →
  /// ponte genérica. `expected` (D-N3) corrige a tela com o NÚMERO:
  /// INSTALLMENT_MISMATCH = a base do pedido mudou no servidor (itens
  /// editados fora desta tela) → decisão tipada para fechar a diferença na
  /// última parcela; MAX_PARCELS_EXCEEDED = limite real da forma → a linha
  /// "até N parcelas" e a validação local passam a usá-lo.
  Future<void> showServerFailure(Failure failure) async {
    final field = failure.fields.isEmpty ? null : failure.fields.first;
    final expected = field?.expected;
    if (expected != null &&
        failure.code == 'INSTALLMENT_MISMATCH' &&
        _editing &&
        _rows.isNotEmpty) {
      return _resolveBaseMismatch(expected);
    }
    await showServerFieldFeedback(context, failure, _pendencyFields());
    if (!mounted || field == null || expected == null) return;
    if (failure.code == 'MAX_PARCELS_EXCEEDED') {
      // Só quando o limite é inequivocamente o da forma do CABEÇALHO: via
      // simples (campo `deadline`) ou grade em que nenhuma linha tem forma
      // própria — o 422 da forma POR PARCELA aponta o mesmo campo
      // `installments` com o limite DELA.
      final headerLimit = field.field == 'deadline' ||
          _rows.every((row) => row.paymentTypeId == null);
      if (headerLimit) setState(() => _maxParcels = expected.round());
    }
  }

  /// Base nova apontada pelo servidor: a tela passa a comparar com ela e
  /// oferece fechar a diferença na ÚLTIMA parcela (Cancelar = o usuário
  /// ajusta à mão; o rodapé já mostra a diferença real e o Salvar segue
  /// travado até fechar).
  Future<void> _resolveBaseMismatch(double expected) async {
    final previous = _base;
    setState(() => _baseOverride = expected);
    final decision = await askDecision(
      context,
      message: 'forms.order.baseChanged'
          .tr(args: [setesMoney(expected), setesMoney(previous)]),
      yesLabel: 'forms.order.adjustLastParcel'.tr(),
    );
    if (decision != SetesDecision.yes || !mounted || _rows.isEmpty) return;
    final last = _rows.last;
    final cents = orderCents(last.amountValue ?? 0) - _diffCents;
    if (cents <= 0) {
      // A diferença não cabe na última parcela — o usuário redistribui.
      last.amountFocus.requestFocus();
      return;
    }
    setState(() => last.amount.text = orderDecimalText(cents / 100));
  }

  // -------------------------------------------------------------------
  // Widgets
  // -------------------------------------------------------------------

  Widget _checkBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SetesText(
        'forms.order.checkKind'.tr(),
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }

  /// Selo "Vencimento no passado" (D-N6) — aviso, nunca bloqueio.
  Widget _pastDueBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history,
              size: 14, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 4),
          SetesText(
            'forms.order.dueDatePast'.tr(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) => SetesCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesText('forms.order.negotiationUnavailable'.tr()),
            const SizedBox(height: 8),
            SetesButton(
              label: 'forms.order.reloadNegotiation'.tr(),
              kind: SetesButtonKind.text,
              icon: Icons.refresh,
              onPressed: _busy ? null : widget.onReload,
            ),
          ],
        ),
      );

  /// Cabeçalho: forma (lookup) + prazo (texto) — somente leitura no
  /// pedido faturado. Abaixo, a base do pedido e o limite de parcelas.
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final negotiation = _negotiation!;
    final isCheck = _paymentTypeKind == kPaymentKindCheck;

    final paymentField = _readOnly
        ? SetesTextField(
            label: 'forms.order.paymentType'.tr(),
            controller: _paymentTypeText,
            readOnly: true,
          )
        : SetesLookupField(
            label: 'forms.order.paymentType'.tr(),
            display: _paymentTypeDescription,
            onSearch: _busy ? () {} : _pickPaymentType,
          );
    final deadlineField = SetesTextField(
      label: 'forms.order.deadline'.tr(),
      hint: 'forms.order.deadlineHint'.tr(),
      controller: _deadline,
      focusNode: _deadlineFocus,
      fieldKey: _deadlineKey,
      readOnly: _readOnly,
      textInputAction: TextInputAction.done,
      validator: (value) => _validateDeadline(value)?.tr(),
      // A nota sob o campo (legado / canônico) só vale enquanto o texto
      // for o gravado; a marca da pendência some ao corrigir.
      onChanged: (_) => setState(() => _revalidateIfMarked(_deadlineKey)),
      onSubmitted: (_) {
        if (_canSave) _save();
      },
    );
    final deadlineNote = _buildDeadlineNote(theme, negotiation.billing);

    final baseText =
        StringBuffer('forms.order.baseRow'.tr(args: [setesMoney(_base)]));
    final max = _maxParcels;
    if (max != null && max > 0) {
      baseText.write(' · ${'forms.order.maxParcelsRow'.tr(args: ['$max'])}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            if (narrow) {
              return Column(
                children: [
                  paymentField,
                  const SizedBox(height: 12),
                  deadlineField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: paymentField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: deadlineField),
              ],
            );
          },
        ),
        if (deadlineNote != null) deadlineNote,
        if (isCheck) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _checkBadge(context),
              const SizedBox(width: 8),
              Flexible(
                child: SetesText(
                  'forms.order.checkHeaderHint'.tr(),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SetesText(
          baseText.toString(),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        // Com a base nova vinda do 422 (`expected`) a composição itens/frete
        // do objeto local está velha — some até a negociação ser relida.
        if (_baseOverride == null)
          SetesText(
            'forms.order.baseDetailRow'.tr(args: [
              setesMoney(negotiation.base.itemsValue),
              setesMoney(negotiation.base.freight),
            ]),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  /// Nota sob o prazo (D-N4), só enquanto o texto é o GRAVADO: legado do
  /// sync tolerado (aviso — ao mexer, a regra estrita vale) ou gravado
  /// válido fora da forma canônica ("será gravado como 030/060").
  Widget? _buildDeadlineNote(ThemeData theme, OrderNegotiationBilling? billing) {
    if (billing == null) return null;
    if (_deadline.text.trim() != (_deadlineRaw ?? '').trim()) return null;
    final String text;
    if (billing.isLegacyDeadline) {
      text = 'forms.order.deadlineLegacy'.tr(args: [_deadlineRaw ?? '']);
    } else if (billing.deadlineNeedsCanonical) {
      text = 'forms.order.deadlineCanonicalHint'.tr(
          args: [billing.deadlineCanonical ?? 'forms.order.deadlineCash'.tr()]);
    } else {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.tertiary),
          const SizedBox(width: 6),
          Flexible(child: SetesText(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  /// Linha SOMENTE LEITURA (preview da via simples ou pedido faturado).
  Widget _buildReadOnlyRow(BuildContext context, OrderNegotiationParcel p) =>
      SetesListTile(
        leading: CircleAvatar(radius: 14, child: SetesText('${p.parcel}')),
        title: SetesText(
            '${isoDateToDisplay(p.dueDate)} · ${setesMoney(p.amount)}'),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: SetesText(p.paymentTypeDescription ?? '')),
            if (p.isCheck) ...[
              const SizedBox(width: 8),
              _checkBadge(context),
            ],
          ],
        ),
      );

  /// Linha EDITÁVEL: nº (sequencial pela posição), vencimento (texto +
  /// calendário), valor e forma por parcela (opcional — vazio herda).
  Widget _buildEditableRow(BuildContext context, int index) {
    final row = _rows[index];
    final number = CircleAvatar(radius: 14, child: SetesText('${index + 1}'));
    final dateField = SetesTextField(
      label: 'forms.order.dueDate'.tr(),
      hint: 'register.dateHint'.tr(),
      controller: row.dueDate,
      focusNode: row.dueDateFocus,
      fieldKey: row.dueDateKey,
      keyboardType: TextInputType.datetime,
      suffixIcon: Icons.calendar_today_outlined,
      onSuffixPressed: _busy ? null : () => _pickDate(row.dueDate),
      validator: (value) => _validateDate(value)?.tr(),
      // Selo de vencimento no passado acompanha a digitação (D-N6); a
      // marca da pendência some ao corrigir.
      onChanged: (_) => setState(() => _revalidateIfMarked(row.dueDateKey)),
    );
    final amountField = SetesTextField(
      label: 'forms.order.amount'.tr(),
      controller: row.amount,
      focusNode: row.amountFocus,
      fieldKey: row.amountKey,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) => _validateAmount(value)?.tr(),
      // Rodapé Soma × Base acompanha a digitação; a marca da pendência
      // some ao corrigir.
      onChanged: (_) => setState(() => _revalidateIfMarked(row.amountKey)),
    );
    final inheritsLabel = _paymentTypeDescription.isEmpty
        ? 'forms.order.parcelInheritsHeader'.tr()
        : 'forms.order.parcelInherits'.tr(args: [_paymentTypeDescription]);
    final ownsType = row.paymentTypeId != null;
    final formField = SetesLookupField(
      label: 'forms.order.parcelPaymentType'.tr(),
      display: ownsType ? (row.paymentTypeDescription ?? '') : inheritsLabel,
      onSearch: _busy ? () {} : () => _pickRowPaymentType(row),
      onClear: ownsType && !_busy ? () => _clearRowPaymentType(row) : null,
    );
    final removeButton = IconButton(
      icon: const Icon(Icons.delete_outline),
      tooltip: 'forms.order.removeParcel'.tr(),
      onPressed: _busy ? null : () => _removeRow(index),
    );
    final isCheck = (ownsType ? row.paymentTypeKind : _paymentTypeKind) ==
        kPaymentKindCheck;
    final pastDue = _isPastDue(row.dueDateIso);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 680;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    number,
                    const SizedBox(width: 8),
                    if (isCheck) _checkBadge(context),
                    if (pastDue) ...[
                      const SizedBox(width: 8),
                      _pastDueBadge(context),
                    ],
                    const Spacer(),
                    removeButton,
                  ],
                ),
                const SizedBox(height: 8),
                dateField,
                const SizedBox(height: 12),
                amountField,
                const SizedBox(height: 12),
                formField,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              number,
              const SizedBox(width: 12),
              Expanded(flex: 3, child: dateField),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: amountField),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: formField),
              if (isCheck) ...[
                const SizedBox(width: 8),
                _checkBadge(context),
              ],
              if (pastDue) ...[
                const SizedBox(width: 8),
                _pastDueBadge(context),
              ],
              removeButton,
            ],
          );
        },
      ),
    );
  }

  /// Rodapé da grade editável: Soma × Base com a diferença destacada.
  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final diff = _diffCents / 100;
    final mismatchStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            SetesText('forms.order.sumRow'.tr(args: [setesMoney(_sum)]),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            SetesText('forms.order.baseCompareRow'.tr(args: [setesMoney(_base)])),
            SetesText(
              'forms.order.differenceRow'.tr(args: [setesMoney(diff)]),
              style: _sumMatches ? null : mismatchStyle,
            ),
          ],
        ),
        if (!_sumMatches) ...[
          const SizedBox(height: 4),
          SetesText(
            'forms.order.sumMismatch'
                .tr(args: [setesMoney(_sum), setesMoney(_base)]),
            style: mismatchStyle,
          ),
        ],
        if (_pastDueCount > 0) ...[
          const SizedBox(height: 4),
          SetesText(
            'forms.order.pastDueDatesRow'.tr(args: ['$_pastDueCount']),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.tertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final theme = Theme.of(context);
    final negotiation = _negotiation!;

    // Faturado: grade elaborada se houver, senão a gerada — só leitura.
    if (_readOnly) {
      final parcels = negotiation.effectiveParcels;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetesText(
            negotiation.isElaborated
                ? 'forms.order.modeElaborated'.tr()
                : 'forms.order.modeSimple'.tr(),
            style: theme.textTheme.titleSmall,
          ),
          if (parcels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SetesText('forms.order.noParcels'.tr()),
            )
          else
            for (final p in parcels) _buildReadOnlyRow(context, p),
        ],
      );
    }

    final modeLabel = _editing
        ? (_savedElaborated
            ? 'forms.order.modeElaborated'.tr()
            : 'forms.order.modeEditing'.tr())
        : 'forms.order.modeSimple'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            SetesText(modeLabel, style: theme.textTheme.titleSmall),
            if (_editing)
              SetesButton(
                label: 'forms.order.backToDeadline'.tr(),
                kind: SetesButtonKind.text,
                icon: Icons.undo,
                onPressed: _busy ? null : _backToDeadline,
              )
            else
              SetesButton(
                label: 'forms.order.negotiateParcels'.tr(),
                kind: SetesButtonKind.text,
                icon: Icons.edit_calendar_outlined,
                onPressed: _busy ? null : _startElaborated,
              ),
          ],
        ),
        if (!_editing) ...[
          if (negotiation.preview.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SetesText('forms.order.noParcels'.tr()),
            )
          else ...[
            SetesText('forms.order.previewHint'.tr(),
                style: theme.textTheme.bodySmall),
            for (final p in negotiation.preview) _buildReadOnlyRow(context, p),
          ],
        ] else ...[
          for (var i = 0; i < _rows.length; i++) ...[
            _buildEditableRow(context, i),
            const Divider(height: 1),
          ],
          const SizedBox(height: 8),
          SetesButton(
            label: 'forms.order.addParcel'.tr(),
            kind: SetesButtonKind.text,
            icon: Icons.add,
            onPressed: _busy ? null : _addRow,
          ),
          const SizedBox(height: 8),
          _buildFooter(context),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_negotiation == null) return _buildUnavailable(context);
    return SetesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(height: 24),
          _buildGrid(context),
          if (!_readOnly) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SetesButton(
                label: 'forms.order.saveNegotiation'.tr(),
                icon: Icons.check,
                onPressed: _canSave ? _save : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
