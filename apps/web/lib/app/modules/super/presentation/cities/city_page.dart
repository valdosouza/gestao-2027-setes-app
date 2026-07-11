import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../register/presentation/register_form_page.dart';
import '../../../register/presentation/register_search_page.dart';
import '../../data/datasource/super_remote_datasource.dart';
import '../../domain/entity/geo_entities.dart';

/// Tela de Cidades (módulo Super).
/// Lista filtrável por nome; formulário completo com ibge, aliq_iss,
/// population, density, area.
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

  Future<void> _save(Map<String, String> values) async {
    final stateId    = int.tryParse(values['tbStateId'] ?? '') ?? 0;
    final name       = values['name'] ?? '';
    final ibge       = values['ibge']?.trim().isEmpty ?? true ? null : values['ibge']!.trim();
    final aliqIss    = double.tryParse(values['aliqIss'] ?? '') ?? 0;
    final population = int.tryParse(values['population'] ?? '') ?? 0;
    final density    = double.tryParse(values['density'] ?? '') ?? 0;
    final area       = double.tryParse(values['area'] ?? '') ?? 0;

    if (_creating) {
      await _ds.createCity(
        tbStateId: stateId, name: name, ibge: ibge,
        aliqIss: aliqIss, population: population, density: density, area: area,
      );
    } else {
      await _ds.updateCity(
        _editing!.id,
        tbStateId: stateId, name: name, ibge: ibge,
        aliqIss: aliqIss, population: population, density: density, area: area,
      );
    }
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  Future<void> _delete() async {
    await _ds.deleteCity(_editing!.id);
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  void _openNew()     => setState(() { _editing = null; _creating = true; });
  void _openEdit(CityEntity c) => setState(() { _editing = c; _creating = false; });
  void _back()        => setState(() { _editing = null; _creating = false; });

  @override
  Widget build(BuildContext context) {
    if (!_creating && _editing == null) {
      return RegisterSearchPage<CityEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        columns: const ['Cidade', 'IBGE'],
        rowBuilder: (c) => [c.name ?? '', c.ibge ?? ''],
        onSearch: _search,
        onNew: _openNew,
        onView: _openEdit,
      );
    }

    return RegisterFormPage(
      title: widget.title,
      initialValues: _editing != null
          ? {
              'tbStateId':  '${_editing!.tbStateId}',
              'name':       _editing!.name ?? '',
              'ibge':       _editing!.ibge ?? '',
              'aliqIss':    '${_editing!.aliqIss}',
              'population': '${_editing!.population}',
              'density':    '${_editing!.density}',
              'area':       '${_editing!.area}',
            }
          : {},
      fields: [
        RegisterField(
          name:         'tbStateId',
          label:        'register.fields.state_id'.tr(),
          keyboardType: TextInputType.number,
          validator:    (v) => (v == null || int.tryParse(v) == null) ? 'register.required'.tr() : null,
        ),
        RegisterField(
          name:      'name',
          label:     'register.fields.name'.tr(),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'register.required'.tr() : null,
        ),
        RegisterField(name: 'ibge',  label: 'register.fields.ibge'.tr()),
        RegisterField(
          name:         'aliqIss',
          label:        'register.fields.aliq_iss'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        RegisterField(
          name:         'population',
          label:        'register.fields.population'.tr(),
          keyboardType: TextInputType.number,
        ),
        RegisterField(
          name:         'density',
          label:        'register.fields.density'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        RegisterField(
          name:         'area',
          label:        'register.fields.area'.tr(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
      onSave:    _save,
      onCancel:  _back,
      onDelete:  _editing != null ? _delete : null,
      canDelete: _editing != null,
    );
  }
}
