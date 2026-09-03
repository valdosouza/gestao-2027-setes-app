import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/service_list_entity.dart';
import '../bloc/service_list_bloc.dart';

/// Tela da Lista de Serviços (LC 116) — interface 'service-list'
/// (1 interface = 1 módulo, ARQUITETURA_MODULOS.md). Referência fiscal do
/// catálogo CENTRAL — acesso: role='super' (guard no backend).
///
/// O ITEM É O PRÓPRIO id (string N.NN, digitado pelo usuário — padrão de
/// código externo, precedente CFOP/BACEN): editável só na inclusão, 409 se
/// já existir, imutável na edição. Incidência (P/E) é radio; Ativo checkbox.
class ServiceListPage extends StatefulWidget {
  const ServiceListPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage>
    with FieldConfigLoader {
  late final ServiceListBloc _bloc;

  /// Acesso ao estado da fábrica: ancora o fields[] do servidor no campo
  /// (showServerFieldError — Framework de Mensagens, Onda B).
  final _formPageKey = GlobalKey<RegisterFormPageState>();

  /// Radio/checkbox — estado da página (extraChildren fica fora dos values
  /// da fábrica).
  String _localIncidence = 'P';
  bool _active = true;

  static const _descriptionMaxLength = 255;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<ServiceListBloc>()
      ..add(const ServiceListListRequested(''));
    loadFieldConfig('service-list'); // engine de campos configuráveis
  }

  void _openNew() {
    setState(() {
      _localIncidence = 'P'; // regra geral da LC 116: município do prestador
      _active = true;
    });
    _bloc.add(const ServiceListNewPressed());
  }

  void _openEdit(ServiceListEntity entity) {
    setState(() {
      _localIncidence = entity.localIncidence;
      _active = entity.active;
    });
    _bloc.add(ServiceListEditPressed(entity));
  }

  String? _validateDescription(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'register.required'.tr();
    if (t.length > _descriptionMaxLength) {
      return 'forms.serviceList.descriptionTooLong'.tr();
    }
    return null;
  }

  /// Item da LC 116: 'N.NN' (1 ou 2 dígitos, ponto, 2 dígitos) — ex. '1.01'.
  String? _validateId(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'register.required'.tr();
    if (!RegExp(r'^[0-9]{1,2}\.[0-9]{2}$').hasMatch(t)) {
      return 'forms.serviceList.idInvalid'.tr();
    }
    return null;
  }

  String _incidenceLabel(String incidence) => incidence == 'E'
      ? 'forms.serviceList.incidenceExecution'.tr()
      : 'forms.serviceList.incidenceProvider'.tr();

  List<Widget> _buildExtraFields() => [
        ExcludeFocusTraversal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Município de incidência do ISS: Prestador × Execução
              SetesRadioGroup<String>(
                label: 'forms.serviceList.localIncidence'.tr(),
                value: _localIncidence,
                options: [
                  SetesRadioOption(
                      value: 'P',
                      label: 'forms.serviceList.incidenceProvider'.tr()),
                  SetesRadioOption(
                      value: 'E',
                      label: 'forms.serviceList.incidenceExecution'.tr()),
                ],
                onChanged: (v) => setState(() => _localIncidence = v ?? 'P'),
              ),
              const SizedBox(height: 8),
              SetesCheckbox(
                label: 'forms.serviceList.active'.tr(),
                value: _active,
                onChanged: (checked) =>
                    setState(() => _active = checked ?? true),
              ),
            ],
          ),
        ),
      ];

  Widget _buildForm(ServiceListFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      key: _formPageKey,
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id':          editing.id,
              'description': editing.description ?? '',
            },
      fields: applyFieldConfig([
        // Item = o PRÓPRIO id da LC 116, digitado na inclusão (padrão
        // código externo — precedente CFOP); imutável na edição.
        RegisterField(
          name:      'id',
          label:     'forms.serviceList.id'.tr(),
          hint:      'forms.serviceList.idHint'.tr(),
          readOnly:  !creating,
          validator: creating ? _validateId : null,
        ),
        RegisterField(
          name:      'description',
          label:     'forms.serviceList.description'.tr(),
          validator: _validateDescription,
        ),
      ], fieldConfig),
      extraChildren: _buildExtraFields(),
      onSave: (values) => _bloc.add(ServiceListSaveRequested(
        item: ServiceListEntity(
          id:             creating ? (values['id'] ?? '').trim() : editing.id,
          description:    (values['description'] ?? '').trim(),
          localIncidence: _localIncidence,
          active:         _active,
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const ServiceListBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(ServiceListDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(ServiceListListState state) =>
      RegisterSearchPage<ServiceListEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'service-list',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (s) => s.id,
        rowBuilder: (s) => [
          s.description ?? '',
          _incidenceLabel(s.localIncidence),
          s.active
              ? 'forms.serviceList.activeRow'.tr()
              : 'forms.serviceList.inactiveRow'.tr(),
        ],
        // Paginação (D1/D3): metadados do estado montam a barra da fábrica;
        // filtro novo volta à página 1; troca de tamanho recarrega na 1
        // (a persistência da escolha é da fábrica — D4).
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(ServiceListListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(ServiceListListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) =>
            _bloc.add(ServiceListListRequested(filter)),
        onNew: _openNew,
        onView: _openEdit,
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ServiceListBloc, ServiceListState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is ServiceListActionSuccess ||
            current is ServiceListActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo do
        // formulário quando ele está montado.
        listener: (context, state) {
          if (state is ServiceListActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as ServiceListActionFailure).failure;
          final form = _formPageKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is ServiceListListState ||
            current is ServiceListFormState,
        builder: (context, state) => switch (state) {
          ServiceListFormState() => _buildForm(state),
          ServiceListListState() => _buildSearch(state),
          _ => _buildSearch(const ServiceListListState(loading: true)),
        },
      );
}
