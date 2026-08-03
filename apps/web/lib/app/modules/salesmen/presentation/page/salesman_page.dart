import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/lookup/entity/role_lookup_entity.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/salesman_datasource.dart';
import '../../domain/entity/object_salesman.dart';
import '../bloc/salesman_bloc.dart';

/// Tela de Vendedores — interface 'salesmen' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Onda 2 da Entidade Única (D1): vendedor é
/// PROMOÇÃO de colaborador — o FAB "novo" NÃO abre form vazio: abre o
/// LOOKUP de colaboradores da institution (showSetesLookup, mesmo padrão do
/// "Abrir OS"); escolhido o colaborador, o form abre com a identificação
/// READONLY e só os campos do papel editáveis. A precedência
/// Collaborator→Salesman morre por construção.
///
/// Colaborador que já é vendedor → 409 DUP_ROLE devolve o id em
/// fields[0].message e a tela oferece abrir a edição (padrão da casa).
class SalesmanPage extends StatefulWidget {
  const SalesmanPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<SalesmanPage> createState() => _SalesmanPageState();
}

class _SalesmanPageState extends State<SalesmanPage> with FieldConfigLoader {
  late final SalesmanBloc _bloc;
  late final SalesmanDatasource _datasource;

  /// Acesso ao estado da fábrica: ancora o fields[] do servidor no campo
  /// (showServerFieldError — Framework de Mensagens, Onda B).
  final _formPageKey = GlobalKey<RegisterFormPageState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<SalesmanBloc>()..add(const SalesmanListRequested(''));
    _datasource = Modular.get<SalesmanDatasource>();
    loadFieldConfig('salesmen'); // engine de campos configuráveis (decisão 7)
  }

  /// FAB "novo" (D1): lookup de COLABORADORES → form de promoção. A lista
  /// de apoio não pagina (regra das listas de apoio).
  Future<void> _promoteNew() async {
    final picked = await showSetesLookup<RoleLookup>(
      context: context,
      title: 'lookup.collaborators'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: _datasource.collaboratorLookup,
      itemId: (c) => c.id,
      itemLabel: (c) => c.name ?? '',
    );
    if (picked != null) {
      _bloc.add(SalesmanPromotePressed(picked.id, picked.name ?? ''));
    }
  }

  /// Aceita vírgula ou ponto; null se vazio/inválido.
  static double? _parseDecimal(String? text) {
    final t = (text ?? '').trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  static String _decimalText(double? value) {
    if (value == null) return '';
    return value % 1 == 0 ? '${value.toInt()}' : '$value';
  }

  /// % Comissão: opcional, decimal, 0–100 (espelho do salesmen.dto.ts).
  String? _validateAliqKickback(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    final parsed = _parseDecimal(t);
    if (parsed == null) return 'register.invalidNumber'.tr();
    if (parsed < 0 || parsed > 100) {
      return 'forms.salesman.aliqKickbackRange'.tr();
    }
    return null;
  }

  /// Valor flex: opcional (vazio assume 0), decimal, nunca negativo.
  String? _validateFlexValue(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    final parsed = _parseDecimal(t);
    if (parsed == null) return 'register.invalidNumber'.tr();
    if (parsed < 0) return 'forms.salesman.flexValueNegative'.tr();
    return null;
  }

  Widget _buildForm(SalesmanFormState state) {
    final draft = state.draft;
    final creating = state.creating;
    return RegisterFormPage(
      key: _formPageKey,
      title: widget.title,
      saving: state.saving,
      initialValues: {
        if (creating)
          'collaboratorName': draft.nickTrade ?? ''
        else ...{
          'nickTrade':   draft.nickTrade ?? '',
          'nameCompany': draft.nameCompany ?? '',
          'document':    draft.document ?? '',
        },
        'aliqKickback': _decimalText(draft.aliqKickback),
        'flexValue':    _decimalText(draft.flexValue),
      },
      fields: applyFieldConfig([
        // Identificação READONLY (D1): a pessoa vem da promoção — o
        // cadastro do vendedor nunca edita a cadeia fiscal.
        if (creating)
          RegisterField(
            name:     'collaboratorName',
            label:    'forms.salesman.collaborator'.tr(),
            readOnly: true,
          )
        else ...[
          RegisterField(
            name:     'nickTrade',
            label:    'forms.salesman.nickTrade'.tr(),
            readOnly: true,
          ),
          RegisterField(
            name:     'nameCompany',
            label:    'forms.salesman.nameCompany'.tr(),
            readOnly: true,
          ),
          RegisterField(
            name:     'document',
            label:    'forms.salesman.document'.tr(),
            readOnly: true,
          ),
        ],
        RegisterField(
          name:         'aliqKickback',
          label:        'forms.salesman.aliqKickback'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator:    _validateAliqKickback,
        ),
        RegisterField(
          name:         'flexValue',
          label:        'forms.salesman.flexValue'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator:    _validateFlexValue,
        ),
      ], fieldConfig),
      // Flags do papel: o estado vive no DRAFT do bloc (nunca nos values
      // do onSave) — checkboxes fora da sequência de Tab (contrato item 8).
      extraChildren: [
        ExcludeFocusTraversal(
          child: SetesCheckbox(
            label: 'forms.salesman.kickbackProduct'.tr(),
            value: draft.kickbackProduct,
            onChanged: (v) => _bloc.add(SalesmanDraftChanged(
                draft.copyWith(kickbackProduct: v ?? false))),
          ),
        ),
        ExcludeFocusTraversal(
          child: SetesCheckbox(
            label: 'forms.salesman.active'.tr(),
            value: draft.active,
            onChanged: (v) => _bloc
                .add(SalesmanDraftChanged(draft.copyWith(active: v ?? true))),
          ),
        ),
      ],
      onSave: (values) => _bloc.add(SalesmanSaveRequested(
        draft: draft.copyWith(
          aliqKickback: () => _parseDecimal(values['aliqKickback']),
          flexValue: _parseDecimal(values['flexValue']) ?? 0,
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const SalesmanBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(SalesmanDeleteRequested(draft.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(SalesmanListState state) =>
      RegisterSearchPage<SalesmanListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'salesmen',
        avatarBuilder: (s) => '${s.id}',
        rowBuilder: (s) => [
          s.nickTrade ?? s.nameCompany ?? '',
          s.nameCompany ?? '',
          s.active
              ? 'forms.salesman.active'.tr()
              : 'forms.salesman.inactive'.tr(),
        ],
        // Paginação (D1/D3): metadados do estado montam a barra da fábrica;
        // filtro novo volta à página 1; troca de tamanho recarrega na 1
        // (a persistência da escolha é da fábrica — D4).
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(SalesmanListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(SalesmanListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) => _bloc.add(SalesmanListRequested(filter)),
        onNew: _promoteNew,
        onView: (item) => _bloc.add(SalesmanEditPressed(item.id)),
      );

  /// 409 de papel duplicado (code DUP_ROLE do catálogo) é uma DECISÃO
  /// tipada via ponte (R4): Sim = abrir o registro existente em edição;
  /// Cancelar (ou fechar) = permanecer no form.
  Future<void> _askDuplicateRole(int existingId) async {
    final decision = await askDecision(
      context,
      message: 'forms.salesman.duplicateRole'.tr(),
      yesLabel: 'forms.salesman.openEdit'.tr(),
    );
    if (decision == SetesDecision.yes && mounted) {
      _bloc.add(SalesmanEditPressed(existingId));
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SalesmanBloc, SalesmanBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is SalesmanActionSuccess ||
            current is SalesmanActionFailure ||
            current is SalesmanDuplicateRole,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo quando
        // o form está montado; DUP_ROLE = decisão tipada (R4).
        listener: (context, state) {
          if (state is SalesmanDuplicateRole) {
            _askDuplicateRole(state.existingId);
            return;
          }
          if (state is SalesmanActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as SalesmanActionFailure).failure;
          final form = _formPageKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is SalesmanListState || current is SalesmanFormState,
        builder: (context, state) => switch (state) {
          SalesmanFormState() => _buildForm(state),
          SalesmanListState() => _buildSearch(state),
          _ => _buildSearch(const SalesmanListState(loading: true)),
        },
      );
}
