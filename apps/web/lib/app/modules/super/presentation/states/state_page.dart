import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../register/presentation/register_form_page.dart';
import '../../../register/presentation/register_search_page.dart';
import '../../data/datasource/super_remote_datasource.dart';
import '../../domain/entity/geo_entities.dart';

/// Tela de Estados (módulo Super).
/// FK tbCountryId inserida como texto — adequado para usuário super (técnico).
class StatePage extends StatefulWidget {
  const StatePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas
  /// (decisão do Valdo 2026-07-11).
  final String title;

  @override
  State<StatePage> createState() => _StatePageState();
}

class _StatePageState extends State<StatePage> {
  late final SuperRemoteDatasource _ds;

  StateEntity? _editing;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _ds = SuperRemoteDatasource(client: Modular.get());
  }

  Future<List<StateEntity>> _search(String filter) async {
    try {
      return await _ds.listStates(filter);
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(Map<String, String> values) async {
    final countryId    = int.tryParse(values['tbCountryId'] ?? '') ?? 0;
    final abbreviation = values['abbreviation'] ?? '';
    final name         = values['name'] ?? '';
    final aliquota     = double.tryParse(values['aliquota'] ?? '');

    if (_creating) {
      await _ds.createState(
        tbCountryId:  countryId,
        abbreviation: abbreviation,
        name:         name,
        aliquota:     aliquota,
      );
    } else {
      await _ds.updateState(
        _editing!.id,
        tbCountryId:  countryId,
        abbreviation: abbreviation,
        name:         name,
        aliquota:     aliquota,
      );
    }
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  Future<void> _delete() async {
    await _ds.deleteState(_editing!.id);
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  void _openNew()      => setState(() { _editing = null; _creating = true; });
  void _openEdit(StateEntity s) => setState(() { _editing = s; _creating = false; });
  void _back()         => setState(() { _editing = null; _creating = false; });

  @override
  Widget build(BuildContext context) {
    if (!_creating && _editing == null) {
      return RegisterSearchPage<StateEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        columns: const ['UF', 'Estado'],
        rowBuilder: (s) => [s.abbreviation ?? '', s.name ?? ''],
        onSearch: _search,
        onNew: _openNew,
        onView: _openEdit,
      );
    }

    return RegisterFormPage(
      title: widget.title,
      initialValues: _editing != null
          ? {
              'tbCountryId':  '${_editing!.tbCountryId}',
              'abbreviation': _editing!.abbreviation ?? '',
              'name':         _editing!.name ?? '',
              'aliquota':     _editing!.aliquota != null ? '${_editing!.aliquota}' : '',
            }
          : {},
      fields: [
        RegisterField(
          name:         'tbCountryId',
          label:        'register.fields.country_id'.tr(),
          keyboardType: TextInputType.number,
          validator:    (v) => (v == null || int.tryParse(v) == null) ? 'register.required'.tr() : null,
        ),
        RegisterField(
          name:      'abbreviation',
          label:     'register.fields.abbreviation'.tr(),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'register.required'.tr() : null,
        ),
        RegisterField(
          name:      'name',
          label:     'register.fields.name'.tr(),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'register.required'.tr() : null,
        ),
        RegisterField(
          name:         'aliquota',
          label:        'register.fields.aliquota'.tr(),
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
