import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../register/presentation/register_form_page.dart';
import '../../../register/presentation/register_search_page.dart';
import '../../data/datasource/super_remote_datasource.dart';
import '../../domain/entity/geo_entities.dart';

/// Tela de Cidades (módulo Super).
/// Padrão fábrica de cadastros (decisão 20): alternância entre pesquisa e
/// formulário no mesmo frame, sem navegação de rota.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código da cidade = código IBGE do município (ex.: Curitiba 4004),
/// informado pelo usuário na inclusão e imutável na edição (decisão do
/// Valdo, 2026-07-11). Estado = FK com lista de apoio (campo-lookup-fk.md):
/// o usuário NUNCA digita o id — escolhe pelo nome no showSetesLookup.
class CityPage extends StatefulWidget {
  const CityPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas
  /// (decisão do Valdo 2026-07-11).
  final String title;

  @override
  State<CityPage> createState() => _CityPageState();
}

class _CityPageState extends State<CityPage> {
  late final SuperRemoteDatasource _ds;

  CityEntity? _editing;
  bool _creating = false;

  /// FK do estado: id salvo + nome exibido (skill campo-lookup-fk.md).
  int? _stateId;
  String _stateName = '';

  @override
  void initState() {
    super.initState();
    _ds = SuperRemoteDatasource(client: Modular.get());
  }

  Future<List<CityEntity>> _search(String filter) async {
    try {
      return await _ds.listCities(filter);
    } catch (_) {
      return [];
    }
  }

  Future<void> _pickState() async {
    final picked = await showSetesLookup<StateEntity>(
      context: context,
      title: 'lookup.states'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: (filter) => _ds.listStates(filter),
      itemId: (s) => s.id,
      itemLabel: (s) => '${s.abbreviation} · ${s.name}',
    );
    if (picked != null) {
      setState(() {
        _stateId = picked.id;
        _stateName = picked.name ?? '';
      });
    }
  }

  /// Alíquota ISS aceita vírgula ou ponto como separador decimal.
  double? _parseAliquota(String? value) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  /// Densidade e Área aceitam vírgula ou ponto como separador decimal.
  double? _parseDouble(String? value) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  Future<void> _save(Map<String, String> values) async {
    final name         = values['name'] ?? '';
    final ibge         = values['ibge']?.trim().isEmpty ?? true ? null : values['ibge']!.trim();
    final aliqIss      = _parseAliquota(values['aliqIss']);
    final population   = int.tryParse(values['population'] ?? '');
    final density      = _parseDouble(values['density']);
    final area         = _parseDouble(values['area']);

    if (_creating) {
      // Código validado no formulário (obrigatório, inteiro positivo).
      final id = int.parse(values['id'] ?? '');
      await _ds.createCity(
        id:         id,
        tbStateId:  _stateId!,
        name:       name,
        ibge:       ibge,
        aliqIss:    aliqIss ?? 0,
        population: population ?? 0,
        density:    density ?? 0,
        area:       area ?? 0,
      );
    } else {
      await _ds.updateCity(
        _editing!.id,
        tbStateId:  _stateId!,
        name:       name,
        ibge:       ibge,
        aliqIss:    aliqIss ?? 0,
        population: population ?? 0,
        density:    density ?? 0,
        area:       area ?? 0,
      );
    }
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  Future<void> _delete() async {
    await _ds.deleteCity(_editing!.id);
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  void _openNew() => setState(() {
        _editing = null;
        _creating = true;
        _stateId = null;
        _stateName = '';
      });

  void _openEdit(CityEntity c) => setState(() {
        _editing = c;
        _creating = false;
        _stateId = c.tbStateId;
        _stateName = c.stateName ?? '';
      });

  void _back() => setState(() { _editing = null; _creating = false; });

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

  @override
  Widget build(BuildContext context) {
    if (!_creating && _editing == null) {
      return RegisterSearchPage<CityEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        columns: const [],
        avatarBuilder: (c) => '${c.id}', // código IBGE
        // Título = nome da cidade; subtítulo = sigla da UF · nome do estado.
        rowBuilder: (c) => [c.name ?? '', c.stateName ?? ''],
        onSearch: _search,
        onNew: _openNew,
        onView: _openEdit,
      );
    }

    // Coluna única (skill, item 2): 8 campos simples, sem grupos naturais.
    // Tab (item 8): Código → Nome → Código IBGE → Alíquota ISS → População →
    // Densidade → Área; lookup e readOnly fora.
    return RegisterFormPage(
      title: widget.title,
      initialValues: _editing != null
          ? {
              'id':         '${_editing!.id}',
              'name':       _editing!.name ?? '',
              'ibge':       _editing!.ibge ?? '',
              'aliqIss':    _editing!.aliqIss != 0 ? '${_editing!.aliqIss}' : '',
              'population': _editing!.population != 0 ? '${_editing!.population}' : '',
              'density':    _editing!.density != 0 ? '${_editing!.density}' : '',
              'area':       _editing!.area != 0 ? '${_editing!.area}' : '',
            }
          : {},
      fields: [
        RegisterField(
          name:         'id',
          label:        'forms.city.code'.tr(),
          keyboardType: TextInputType.number,
          readOnly:     !_creating, // código IBGE imutável na edição
          validator:    _creating ? _validateCode : null,
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
          name:      'ibge',
          label:     'forms.city.ibge'.tr(),
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
      onSave:    _save,
      onCancel:  _back,
      onDelete:  _editing != null ? _delete : null,
      canDelete: _editing != null,
    );
  }
}
