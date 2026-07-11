import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../register/presentation/register_form_page.dart';
import '../../../register/presentation/register_search_page.dart';
import '../../data/datasource/super_remote_datasource.dart';
import '../../domain/entity/geo_entities.dart';

/// Tela de Países (módulo Super).
/// Padrão fábrica de cadastros (decisão 20): alternância entre pesquisa e
/// formulário no mesmo frame, sem navegação de rota.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código do país = padrão mundial BACEN (ex.: Brasil 1058), informado pelo
/// usuário na inclusão e imutável na edição (decisão do Valdo, 2026-07-10).
class CountryPage extends StatefulWidget {
  const CountryPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas
  /// (decisão do Valdo 2026-07-11).
  final String title;

  @override
  State<CountryPage> createState() => _CountryPageState();
}

class _CountryPageState extends State<CountryPage> {
  late final SuperRemoteDatasource _ds;

  CountryEntity? _editing;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _ds = SuperRemoteDatasource(client: Modular.get());
  }

  Future<List<CountryEntity>> _search(String filter) async {
    try {
      return await _ds.listCountries(filter);
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(Map<String, String> values) async {
    final name = values['name'] ?? '';
    if (_creating) {
      // Código validado no formulário (obrigatório, inteiro positivo).
      final id = int.parse(values['id'] ?? '');
      await _ds.createCountry(id: id, name: name);
    } else {
      await _ds.updateCountry(_editing!.id, name); // PUT não altera o id
    }
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  Future<void> _delete() async {
    await _ds.deleteCountry(_editing!.id);
    if (mounted) setState(() { _editing = null; _creating = false; });
  }

  void _openNew()     => setState(() { _editing = null; _creating = true; });
  void _openEdit(CountryEntity c) => setState(() { _editing = c; _creating = false; });
  void _back()        => setState(() { _editing = null; _creating = false; });

  String? _validateCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'register.required'.tr();
    final code = int.tryParse(text);
    if (code == null || code <= 0) return 'register.invalidNumber'.tr();
    return null;
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  @override
  Widget build(BuildContext context) {
    if (!_creating && _editing == null) {
      return RegisterSearchPage<CountryEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        columns: const [],
        avatarBuilder: (c) => '${c.id}',
        rowBuilder: (c) => [c.name ?? ''],
        onSearch: _search,
        onNew: _openNew,
        onView: _openEdit,
      );
    }

    return RegisterFormPage(
      title: widget.title,
      initialValues: _editing != null
          ? {'id': '${_editing!.id}', 'name': _editing!.name ?? ''}
          : {},
      fields: [
        RegisterField(
          name:         'id',
          label:        'forms.country.code'.tr(),
          keyboardType: TextInputType.number,
          readOnly:     !_creating, // código imutável na edição
          validator:    _creating ? _validateCode : null,
        ),
        RegisterField(
          name:      'name',
          label:     'forms.country.name'.tr(),
          validator: _validateRequired,
        ),
      ],
      onSave:    _save,
      onCancel:  _back,
      onDelete:  _editing != null ? _delete : null,
      canDelete: _editing != null,
    );
  }
}
