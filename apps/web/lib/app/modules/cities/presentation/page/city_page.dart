import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/lookup/entity/state_lookup_entity.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/city_entity.dart';
import '../bloc/city_bloc.dart';

/// Tela de Cidades — interface 'cities' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Pesquisa ↔ formulário orquestrados pelo
/// CityBloc; a página só traduz estados em widgets da fábrica.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código da cidade = código IBGE do município (Curitiba 4004), informado
/// na inclusão e imutável na edição (decisão do Valdo 2026-07-11).
/// Estado = FK com lista de apoio via shared/lookup (campo-lookup-fk.md):
/// o usuário NUNCA digita o id — escolhe pelo nome no showSetesLookup.
class CityPage extends StatefulWidget {
  const CityPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<CityPage> createState() => _CityPageState();
}

class _CityPageState extends State<CityPage> {
  late final CityBloc _bloc;
  late final StateLookupDatasource _stateLookup;

  /// FK do estado: id salvo + nome exibido (skill campo-lookup-fk.md).
  int? _stateId;
  String _stateName = '';

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CityBloc>()..add(const CityListRequested(''));
    _stateLookup = Modular.get<StateLookupDatasource>();
  }

  Future<void> _pickState() async {
    final picked = await showSetesLookup<StateLookup>(
      context: context,
      title: 'lookup.states'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: _stateLookup.list,
      itemId: (s) => s.id,
      itemLabel: (s) => '${s.abbreviation ?? ''} · ${s.name ?? ''}',
    );
    if (picked != null) {
      setState(() {
        _stateId = picked.id;
        _stateName = picked.name ?? '';
      });
    }
  }

  /// Decimais aceitam vírgula ou ponto como separador.
  double? _parseDouble(String? value) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _openNew() {
    setState(() {
      _stateId = null;
      _stateName = '';
    });
    _bloc.add(const CityNewPressed());
  }

  void _openEdit(CityEntity city) {
    setState(() {
      _stateId = city.tbStateId;
      _stateName = city.stateName ?? '';
    });
    _bloc.add(CityEditPressed(city));
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

  String? _validateNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // opcional
    return int.tryParse(text) == null ? 'register.invalidNumber'.tr() : null;
  }

  String? _validateDecimal(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // opcional
    return _parseDouble(text) == null ? 'register.invalidNumber'.tr() : null;
  }

  Widget _buildForm(CityFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id':         '${editing.id}',
              'name':       editing.name ?? '',
              'ibge':       editing.ibge ?? '',
              'aliqIss':    editing.aliqIss != 0 ? '${editing.aliqIss}' : '',
              'population': editing.population != 0 ? '${editing.population}' : '',
              'density':    editing.density != 0 ? '${editing.density}' : '',
              'area':       editing.area != 0 ? '${editing.area}' : '',
            },
      fields: [
        RegisterField(
          name:         'id',
          label:        'forms.city.code'.tr(),
          keyboardType: TextInputType.number,
          readOnly:     !creating, // código IBGE imutável na edição
          validator:    creating ? _validateCode : null,
        ),
        RegisterField.lookup(
          name:             'tbStateId',
          label:            'forms.city.state'.tr(),
          display:          _stateName,
          onPick:           _pickState,
          validatorMessage: 'register.required'.tr(),
        ),
        RegisterField(
          name:      'name',
          label:     'forms.city.name'.tr(),
          validator: _validateRequired,
        ),
        RegisterField(
          name:  'ibge',
          label: 'forms.city.ibge'.tr(),
        ),
        RegisterField(
          name:         'aliqIss',
          label:        'forms.city.aliqIss'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator:    _validateDecimal,
        ),
        RegisterField(
          name:         'population',
          label:        'forms.city.population'.tr(),
          keyboardType: TextInputType.number,
          validator:    _validateNumber,
        ),
        RegisterField(
          name:         'density',
          label:        'forms.city.density'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator:    _validateDecimal,
        ),
        RegisterField(
          name:         'area',
          label:        'forms.city.area'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator:    _validateDecimal,
        ),
      ],
      onSave: (values) => _bloc.add(CitySaveRequested(
        city: CityEntity(
          id:         int.parse(values['id']!),
          tbStateId:  _stateId!,
          name:       values['name'] ?? '',
          ibge:       (values['ibge'] ?? '').isEmpty ? null : values['ibge'],
          aliqIss:    _parseDouble(values['aliqIss']) ?? 0,
          population: int.tryParse(values['population'] ?? '') ?? 0,
          density:    _parseDouble(values['density']) ?? 0,
          area:       _parseDouble(values['area']) ?? 0,
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const CityBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(CityDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(CityListState state) => RegisterSearchPage<CityEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        avatarBuilder: (c) => '${c.id}', // código IBGE do município
        rowBuilder: (c) => [c.name ?? '', c.stateName ?? ''],
        onFilterChanged: (filter) => _bloc.add(CityListRequested(filter)),
        onNew: _openNew,
        onView: _openEdit,
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<CityBloc, CityState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CityActionSuccess || current is CityActionFailure,
        listener: (context, state) {
          final message = state is CityActionSuccess
              ? state.messageKey.tr()
              : (state as CityActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is CityListState || current is CityFormState,
        builder: (context, state) => switch (state) {
          CityFormState() => _buildForm(state),
          CityListState() => _buildSearch(state),
          _ => _buildSearch(const CityListState(loading: true)),
        },
      );
}
