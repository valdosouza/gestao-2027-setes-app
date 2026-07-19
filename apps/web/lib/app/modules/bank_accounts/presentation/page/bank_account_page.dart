import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/bank_account_datasource.dart';
import '../../domain/entity/bank_account_entity.dart';
import '../bloc/bank_account_bloc.dart';

/// Tela de Contas Bancárias — interface 'bank-accounts', grupo Financeiro
/// (Módulo Software House, seção 5.6 do prompt fechado).
///
/// Lista = contas da institution com banco (catálogo central FEBRABAN),
/// agência/conta e gerente. Form = banco (lookup /api/bank-accounts/banks),
/// agência + DV e conta + DV lado a lado, datas de abertura/contrato,
/// telefone, gerente e limite.
class BankAccountPage extends StatefulWidget {
  const BankAccountPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<BankAccountPage> createState() => _BankAccountPageState();
}

class _BankAccountPageState extends State<BankAccountPage> {
  late final BankAccountBloc _bloc;
  late final BankAccountDatasource _datasource;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<BankAccountBloc>()
      ..add(const BankAccountListRequested('', refresh: true));
    _datasource = Modular.get<BankAccountDatasource>();
  }

  Widget _buildSearch(BankAccountListState state) =>
      RegisterSearchPage<BankAccountListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'bank-accounts',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (a) =>
            (a.bankNumber != null && a.bankNumber!.isNotEmpty)
                ? a.bankNumber!
                : '${a.id}',
        rowBuilder: (a) => [
          a.bankDisplay,
          'forms.bankAccount.accountRow'
              .tr(args: [a.agencyDisplay, a.numberDisplay]),
          if (a.manager != null && a.manager!.isNotEmpty)
            'forms.bankAccount.managerRow'.tr(args: [a.manager!]),
        ],
        onFilterChanged: (filter) => _bloc.add(BankAccountListRequested(filter)),
        onNew: () => _bloc.add(const BankAccountNewPressed()),
        onView: (a) => _bloc.add(BankAccountEditPressed(a.id)),
      );

  Widget _buildForm(BankAccountFormState state) => _BankAccountFormView(
        key: ValueKey(state.editing?.id ?? 'bank-account-new'),
        title: widget.title,
        state: state,
        datasource: _datasource,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const BankAccountBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(BankAccountDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BankAccountBloc, BankAccountState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is BankAccountActionSuccess ||
            current is BankAccountActionFailure,
        listener: (context, state) {
          final message = state is BankAccountActionSuccess
              ? state.messageKey.tr()
              : (state as BankAccountActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is BankAccountListState || current is BankAccountFormState,
        builder: (context, state) => switch (state) {
          BankAccountFormState() => _buildForm(state),
          BankAccountListState() => _buildSearch(state),
          _ => _buildSearch(const BankAccountListState(loading: true)),
        },
      );
}

/// Form da conta bancária (SetesFormShell): banco (lookup do catálogo
/// central FEBRABAN) + agência/DV e conta/DV lado a lado + datas +
/// telefone + gerente + limite.
class _BankAccountFormView extends StatefulWidget {
  const _BankAccountFormView({
    required this.title,
    required this.state,
    required this.datasource,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final BankAccountFormState state;
  final BankAccountDatasource datasource;
  final void Function(BankAccountSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_BankAccountFormView> createState() => _BankAccountFormViewState();
}

class _BankAccountFormViewState extends State<_BankAccountFormView> {
  late final TextEditingController _agency;
  late final TextEditingController _agencyDv;
  late final TextEditingController _number;
  late final TextEditingController _numberDv;
  late final TextEditingController _dtOpening;
  late final TextEditingController _phone;
  late final TextEditingController _manager;
  late final TextEditingController _limitValue;
  late final TextEditingController _dtContract;

  /// Banco escolhido no lookup — id salvo, "número - descrição" exibido.
  int? _bankId;
  String _bankDisplay = '';

  BankAccountFull? get _editing => widget.state.editing;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _bankId      = editing?.bankId;
    _bankDisplay = editing?.bankDisplay ?? '';
    _agency     = TextEditingController(text: editing?.agency ?? '');
    _agencyDv   = TextEditingController(text: editing?.agencyDv ?? '');
    _number     = TextEditingController(text: editing?.number ?? '');
    _numberDv   = TextEditingController(text: editing?.numberDv ?? '');
    _dtOpening  = TextEditingController(text: isoDateToDisplay(editing?.dtOpening));
    _phone      = TextEditingController(text: editing?.phone ?? '');
    _manager    = TextEditingController(text: editing?.manager ?? '');
    _limitValue = TextEditingController(
        text: editing?.limitValue == null
            ? ''
            : editing!.limitValue!.toStringAsFixed(2).replaceAll('.', ','));
    _dtContract = TextEditingController(text: isoDateToDisplay(editing?.dtContract));
  }

  @override
  void dispose() {
    _agency.dispose();
    _agencyDv.dispose();
    _number.dispose();
    _numberDv.dispose();
    _dtOpening.dispose();
    _phone.dispose();
    _manager.dispose();
    _limitValue.dispose();
    _dtContract.dispose();
    super.dispose();
  }

  Future<void> _pickBank() async {
    final picked = await showSetesLookup<BankLookup>(
      context: context,
      title: 'lookup.banks'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.banks,
      itemId: (b) => b.id,
      itemLabel: (b) => b.display,
    );
    if (picked != null) {
      setState(() {
        _bankId      = picked.id;
        _bankDisplay = picked.display;
      });
    }
  }

  void _warn(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  /// null limpo, '' vira null (a API aceita nullable).
  static String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _save() {
    if (_bankId == null) {
      _warn('register.requiredField'.tr(args: ['forms.bankAccount.bank'.tr()]));
      return;
    }
    final agency = _agency.text.trim();
    if (agency.isEmpty) {
      _warn('register.requiredField'
          .tr(args: ['forms.bankAccount.agency'.tr()]));
      return;
    }
    final number = _number.text.trim();
    if (number.isEmpty) {
      _warn('register.requiredField'
          .tr(args: ['forms.bankAccount.number'.tr()]));
      return;
    }
    String? dtOpeningIso;
    if (_dtOpening.text.trim().isNotEmpty) {
      dtOpeningIso = displayDateToIso(_dtOpening.text);
      if (dtOpeningIso == null) {
        _warn('register.invalidDate'.tr());
        return;
      }
    }
    String? dtContractIso;
    if (_dtContract.text.trim().isNotEmpty) {
      dtContractIso = displayDateToIso(_dtContract.text);
      if (dtContractIso == null) {
        _warn('register.invalidDate'.tr());
        return;
      }
    }
    double? limitValue;
    final limitText = _limitValue.text.trim();
    if (limitText.isNotEmpty) {
      // Parse pt-BR: "1.234,56" → 1234.56 (vírgula decimal).
      limitValue =
          double.tryParse(limitText.replaceAll('.', '').replaceAll(',', '.'));
      if (limitValue == null || limitValue < 0) {
        _warn('forms.bankAccount.limitInvalid'.tr());
        return;
      }
    }
    widget.onSave(BankAccountSaveRequested(
      editingId: _editing?.id,
      input: BankAccountInput(
        bankId:     _bankId!,
        agency:     agency,
        agencyDv:   _optional(_agencyDv),
        number:     number,
        numberDv:   _optional(_numberDv),
        dtOpening:  dtOpeningIso,
        phone:      _optional(_phone),
        manager:    _optional(_manager),
        limitValue: limitValue,
        dtContract: dtContractIso,
      ),
    ));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('register.confirmDelete'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'register.delete'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Tabulação (criar-formulario-cadastro.md, item 8): Tab só nos campos
    // editáveis na ordem declarada; o lookup fica fora da sequência.
    var order = 0;
    Widget field(Widget child) => FocusTraversalOrder(
        order: NumericFocusOrder((++order).toDouble()), child: child);

    return SetesFormShell(
      title: widget.title,
      saving: widget.state.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SetesLookupField(
              label: 'forms.bankAccount.bank'.tr(),
              display: _bankDisplay,
              onSearch: _pickBank,
              onClear: () => setState(() {
                _bankId = null;
                _bankDisplay = '';
              }),
            ),
            const SizedBox(height: 16),
            // Agência + DV lado a lado (DV curto).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: field(SetesTextField(
                    label: 'forms.bankAccount.agency'.tr(),
                    controller: _agency,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(8)],
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(SetesTextField(
                    label: 'forms.bankAccount.agencyDv'.tr(),
                    controller: _agencyDv,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(2)],
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Conta + DV lado a lado (DV curto).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: field(SetesTextField(
                    label: 'forms.bankAccount.number'.tr(),
                    controller: _number,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(SetesTextField(
                    label: 'forms.bankAccount.numberDv'.tr(),
                    controller: _numberDv,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(2)],
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.bankAccount.dtOpening'.tr(),
              hint: 'register.dateHint'.tr(),
              controller: _dtOpening,
              textInputAction: TextInputAction.next,
              validator: validateOptionalDate,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.bankAccount.phone'.tr(),
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.bankAccount.manager'.tr(),
              controller: _manager,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(25)],
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.bankAccount.limitValue'.tr(),
              controller: _limitValue,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.bankAccount.dtContract'.tr(),
              hint: 'register.dateHint'.tr(),
              controller: _dtContract,
              textInputAction: TextInputAction.done,
              validator: validateOptionalDate,
            )),
          ],
        ),
      ),
    );
  }
}
