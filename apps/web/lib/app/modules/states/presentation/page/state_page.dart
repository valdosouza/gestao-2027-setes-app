import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../../../shared/lookup/entity/country_lookup_entity.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/state_entity.dart';
import '../bloc/state_bloc.dart';

/// Tela de Estados — interface 'states' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Pesquisa ↔ formulário orquestrados pelo
/// StateBloc; a página só traduz estados em widgets da fábrica.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código do estado = código IBGE da UF (Paraná 41), informado na inclusão
/// e imutável na edição (decisão do Valdo 2026-07-11). País = FK com lista
/// de apoio via shared/lookup (campo-lookup-fk.md): o usuário NUNCA digita
/// o id — escolhe pelo nome no showSetesLookup.
class StatePage extends StatefulWidget {
  const StatePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<StatePage> createState() => _StatePageState();
}

class _StatePageState extends State<StatePage> {
  late final StateBloc _bloc;
  late final CountryLookupDatasource _countryLookup;

  /// FK do país: id salvo + nome exibido (skill campo-lookup-fk.md).
  int? _countryId;
  String _countryName = '';

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<StateBloc>()..add(const StateListRequested(''));
    _countryLookup = Modular.get<CountryLookupDatasource>();
  }

  Future<void> _pickCountry() async {
    final picked = await showSetesLookup<CountryLookup>(
      context: context,
      title: 'lookup.countries'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: _countryLookup.list,
      itemId: (c) => c.id,
      itemLabel: (c) => c.name ?? '',
    );
    if (picked != null) {
      setState(() {
        _countryId = picked.id;
        _countryName = picked.name ?? '';
      });
    }
  }

  /// Alíquota aceita vírgula ou ponto como separador decimal.
  double? _parseAliquota(String? value) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _openNew() {
    setState(() {
      _countryId = null;
      _countryName = '';
    });
    _bloc.add(const StateNewPressed());
  }

  void _openEdit(StateEntity state) {
    setState(() {
      _countryId = state.tbCountryId;
      _countryName = state.countryName ?? '';
    });
    _bloc.add(StateEditPressed(state));
  }

  String? _validateCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'register.required'.tr();
    final code = int.tryParse(text);
    if (code == null || code <= 0) return 'register.invalidNumber'.tr();
    return null;
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  String? _validateDecimal(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // opcional
    return _parseAliquota(text) == null ? 'register.invalidNumber'.tr() : null;
  }

  Widget _buildForm(StateFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id':           '${editing.id}',
              'abbreviation': editing.abbreviation ?? '',
              'name':         editing.name ?? '',
              'aliquota':     editing.aliquota != null ? '${editing.aliquota}' : '',
            },
      fields: [
        RegisterField(
          name:         'id',
          label:        'forms.state.code'.tr(),
          keyboardType: TextInputType.number,
          readOnly:     !creating, // código IBGE imutável na edição
          validator:    creating ? _validateCode : null,
        ),
        RegisterField.lookup(
          name:             'tbCountryId',
          label:            'forms.state.country'.tr(),
          display:          _countryName,
          onPick:           _pickCountry,
          validatorMessage: 'register.required'.tr(),
        ),
        RegisterField(
          name:      'abbreviation',
          label:     'forms.state.abbreviation'.tr(),
          validator: _validateRequired,
        ),
        RegisterField(
          name:      'name',
          label:     'forms.state.name'.tr(),
          validator: _validateRequired,
        ),
        RegisterField(
          name:         'aliquota',
          label:        'forms.state.aliquota'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator:    _validateDecimal,
        ),
      ],
      onSave: (values) => _bloc.add(StateSaveRequested(
        state: StateEntity(
          id:           int.parse(values['id']!),
          tbCountryId:  _countryId!,
          abbreviation: values['abbreviation'] ?? '',
          name:         values['name'] ?? '',
          aliquota:     _parseAliquota(values['aliquota']),
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const StateBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(StateDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(StateListState state) => RegisterSearchPage<StateEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        avatarBuilder: (s) => '${s.id}', // código IBGE da UF
        rowBuilder: (s) => [
          s.name ?? '',
          s.abbreviation ?? '',
          s.countryName ?? '',
        ],
        onFilterChanged: (filter) => _bloc.add(StateListRequested(filter)),
        onNew: _openNew,
        onView: _openEdit,
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<StateBloc, StateBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is StateActionSuccess || current is StateActionFailure,
        listener: (context, state) {
          final message = state is StateActionSuccess
              ? state.messageKey.tr()
              : (state as StateActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is StateListState || current is StateFormState,
        builder: (context, state) => switch (state) {
          StateFormState() => _buildForm(state),
          StateListState() => _buildSearch(state),
          _ => _buildSearch(const StateListState(loading: true)),
        },
      );
}
