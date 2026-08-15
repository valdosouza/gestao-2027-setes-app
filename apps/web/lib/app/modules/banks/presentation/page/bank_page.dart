import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_validators/setes_validators.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/bank_entity.dart';
import '../bloc/bank_bloc.dart';

/// Tela de Bancos — interface 'banks' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Pesquisa ↔ formulário orquestrados pelo
/// BankBloc; a página só traduz estados em widgets da fábrica.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Catálogo FEBRABAN central (decisão do Valdo 2026-08-04, fecho da
/// decisão 8 da Fase 3): id INTERNO gerado pelo backend (MAX+1 — campo
/// readOnly, vazio na inclusão e preenchido na edição); número FEBRABAN
/// (3 dígitos) digitado pelo usuário, ÚNICO (409 ancorado no campo) e
/// editável na correção — não é a PK.
class BankPage extends StatefulWidget {
  const BankPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<BankPage> createState() => _BankPageState();
}

class _BankPageState extends State<BankPage> with FieldConfigLoader {
  late final BankBloc _bloc;

  /// Acesso ao estado da fábrica: ancora o fields[] do servidor no campo
  /// (showServerFieldError — Framework de Mensagens, Onda B).
  final _formPageKey = GlobalKey<RegisterFormPageState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<BankBloc>()..add(const BankListRequested(''));
    loadFieldConfig('banks'); // engine de campos configuráveis (decisão 7)
  }

  Widget _buildForm(BankFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      key: _formPageKey,
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id':          '${editing.id}',
              'number':      editing.number ?? '',
              'description': editing.description ?? '',
            },
      fields: applyFieldConfig([
        // Código gerado pelo backend (MAX+1): sempre readOnly — vazio na
        // inclusão, preenchido na edição (precedente privileges/interfaces).
        RegisterField(
          name:     'id',
          label:    'forms.bank.code'.tr(),
          readOnly: true,
        ),
        // Número FEBRABAN: exatamente 3 dígitos (catálogo do seed 25 + DTO
        // Zod /^\d{3}$/ — as duas fontes da validação, R6).
        RegisterField(
          name:         'number',
          label:        'forms.bank.number'.tr(),
          keyboardType: TextInputType.number,
          mask:         '###',
          validator: SetesValidators.compose([
            SetesValidators.required(),
            SetesValidators.mask('###', message: 'forms.bank.numberInvalid'),
          ]),
        ),
        RegisterField(
          name:  'description',
          label: 'forms.bank.description'.tr(),
          validator: SetesValidators.compose([
            SetesValidators.required(),
            SetesValidators.maxLength(100),
          ]),
        ),
      ], fieldConfig),
      onSave: (values) => _bloc.add(BankSaveRequested(
        bank: BankEntity(
          id:          creating ? 0 : editing.id, // ignorado no POST
          number:      values['number'] ?? '',
          description: values['description'] ?? '',
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const BankBackToListPressed()),
      onDelete:
          creating ? null : () => _bloc.add(BankDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(BankListState state) => RegisterSearchPage<BankEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'banks',
        items: state.items,
        loading: state.loading,
        // O avatar mostra o número FEBRABAN — é o código que identifica o
        // banco no mundo real (a API já ordena a lista por ele).
        avatarBuilder: (b) => b.number ?? '${b.id}',
        rowBuilder: (b) => [b.description ?? ''],
        // Paginação (D1/D3): metadados do estado montam a barra da fábrica;
        // filtro novo volta à página 1; troca de tamanho recarrega na 1
        // (a persistência da escolha é da fábrica — D4).
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(BankListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(BankListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) => _bloc.add(BankListRequested(filter)),
        onNew: () => _bloc.add(const BankNewPressed()),
        onView: (b) => _bloc.add(BankEditPressed(b)),
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<BankBloc, BankState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is BankActionSuccess || current is BankActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo do
        // formulário quando ele está montado (ex.: 409 de number em uso).
        listener: (context, state) {
          if (state is BankActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as BankActionFailure).failure;
          final form = _formPageKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is BankListState || current is BankFormState,
        builder: (context, state) => switch (state) {
          BankFormState() => _buildForm(state),
          BankListState() => _buildSearch(state),
          _ => _buildSearch(const BankListState(loading: true)),
        },
      );
}
