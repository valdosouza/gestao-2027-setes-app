import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../register/presentation/register_form_page.dart';
import '../../../register/presentation/register_search_page.dart';
import '../../data/datasource/super_remote_datasource.dart';
import '../../domain/entity/geo_entities.dart';

/// Tela de Estados (módulo Super).
/// Padrão fábrica de cadastros (decisão 20): alternância entre pesquisa e
/// formulário no mesmo frame, sem navegação de rota.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código do estado = código IBGE da UF (ex.: Paraná 41, São Paulo 35),
/// informado pelo usuário na inclusão e imutável na edição (decisão do
/// Valdo, 2026-07-11). País = FK com lista de apoio (campo-lookup-fk.md):
/// o usuário NUNCA digita o id — escolhe pelo nome no showSetesLookup.
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

  /// FK do país: id salvo + nome exibido (skill campo-lookup-fk.md).
  int? _countryId;
  String _countryName = '';

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

  Future<void> _pickCountry() async {
    final picked = await showSetesLookup<CountryEntity>(
      context: context,
      title: 'lookup.countries'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: _ds.listCountries,
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

  Future<void> _save(Map<String, String> values) async {
    final abbreviation = values['abbreviation'] ?? '';
    final name         = values['name'] ?? '';
    final aliquota     = _parseAliquota(values['aliquota']);

    if (_creating) {
      // Código validado no formulário (obrigatório, inteiro positivo).
      final id = int.parse(values['id'] ?? '');
      await _ds.createState(
        id:           id,
        tbCountryId:  _countryId!,
        abbreviation: abbreviation,
        name:         name,
        aliquota:     aliquota,
      );
    } else {
      await _ds.updateState(
        _editing!.id, // PUT não altera o id
        tbCountryId:  _countryId!,
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

  void _openNew() => setState(() {
        _editing = null;
        _creating = true;
        _countryId = null;
        _countryName = '';
      });

  void _openEdit(StateEntity s) => setState(() {
        _editing = s;
        _creating = false;
        _countryId = s.tbCountryId;
        _countryName = s.countryName ?? '';
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

  String? _validateAliquota(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // opcional
    return _parseAliquota(text) == null ? 'register.invalidNumber'.tr() : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_creating && _editing == null) {
      return RegisterSearchPage<StateEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        columns: const [],
        avatarBuilder: (s) => '${s.id}', // código IBGE
        // Título = nome do estado; subtítulo = sigla · nome do país.
        rowBuilder: (s) => [s.name ?? '', s.abbreviation ?? '', s.countryName ?? ''],
        onSearch: _search,
        onNew: _openNew,
        onView: _openEdit,
      );
    }

    // Coluna única (skill, item 2): 5 campos simples, sem grupos naturais.
    // Tab (item 8): Código → Sigla → Nome → Alíquota; lookup e readOnly fora.
    return RegisterFormPage(
      title: widget.title,
      initialValues: _editing != null
          ? {
              'id':           '${_editing!.id}',
              'abbreviation': _editing!.abbreviation ?? '',
              'name':         _editing!.name ?? '',
              'aliquota':     _editing!.aliquota != null ? '${_editing!.aliquota}' : '',
            }
          : {},
      fields: [
        RegisterField(
          name:         'id',
          label:        'forms.state.code'.tr(),
          keyboardType: TextInputType.number,
          readOnly:     !_creating, // código IBGE imutável na edição
          validator:    _creating ? _validateCode : null,
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
          validator:    _validateAliquota,
        ),
      ],
      onSave:    _save,
      onCancel:  _back,
      onDelete:  _editing != null ? _delete : null,
      canDelete: _editing != null,
    );
  }
}
