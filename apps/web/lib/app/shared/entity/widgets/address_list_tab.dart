import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../lookup/datasource/city_lookup_datasource.dart';
import '../../lookup/datasource/country_lookup_datasource.dart';
import '../../lookup/datasource/state_lookup_datasource.dart';
import '../../lookup/entity/city_lookup_entity.dart';
import '../../lookup/entity/country_lookup_entity.dart';
import '../../lookup/entity/state_lookup_entity.dart';
import '../domain/object_entity.dart';
import 'entity_list_common.dart';

/// Aba "Endereços" da cadeia de entidade fiscal — COMPARTILHADA
/// (skill cadastro-entidade-fiscal.md). CRUD inline no padrão do
/// customer_register: lista + dialog de add/edit + remover com confirmação.
/// País/UF/Cidade via lookups de app/shared/lookup (campo-lookup-fk.md);
/// cidade é lookup DEPENDENTE: só abre depois de escolher a UF.
class AddressListTab extends StatelessWidget {
  const AddressListTab({
    required this.items,
    required this.onChanged,
    required this.countryLookup,
    required this.stateLookup,
    required this.cityLookup,
    super.key,
  });

  final List<EntityAddress> items;
  final ValueChanged<List<EntityAddress>> onChanged;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;

  Future<void> _openDialog(BuildContext context, {int? index}) async {
    final editing = index != null ? items[index] : null;
    final takenKinds = {
      for (final (i, item) in items.indexed)
        if (i != index) item.kind,
    };
    final result = await showDialog<EntityAddress>(
      context: context,
      builder: (_) => _AddressDialog(
        editing: editing,
        takenKinds: takenKinds,
        countryLookup: countryLookup,
        stateLookup: stateLookup,
        cityLookup: cityLookup,
      ),
    );
    if (result == null) return;
    final updated = [...items];
    if (index != null) {
      updated[index] = result;
    } else {
      updated.add(result);
    }
    onChanged(updated);
  }

  Future<void> _remove(BuildContext context, int index) async {
    if (!await confirmEntityItemDelete(context)) return;
    onChanged([...items]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) => EntityListScaffold(
        heroTag: 'entity_address_add',
        itemCount: items.length,
        onAdd: () => _openDialog(context),
        itemBuilder: (context, index) {
          final a = items[index];
          final place = [
            '${a.street}, ${a.nmbr ?? ''}'.trim(),
            if ((a.neighborhood ?? '').isNotEmpty) a.neighborhood!,
            if ((a.cityName ?? '').isNotEmpty)
              '${a.cityName} - ${a.stateName ?? ''}',
            if (a.main) 'forms.address.main'.tr(),
          ].join(' · ');
          return SetesListTile(
            leading: CircleAvatar(
                child: SetesText(a.kind.isNotEmpty ? a.kind[0] : '?')),
            title: SetesText(a.kind),
            subtitle: SetesText(place),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _remove(context, index),
            ),
            onTap: () => _openDialog(context, index: index),
          );
        },
      );
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({
    required this.editing,
    required this.takenKinds,
    required this.countryLookup,
    required this.stateLookup,
    required this.cityLookup,
  });

  final EntityAddress? editing;
  final Set<String> takenKinds;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _kind;
  late final TextEditingController _street;
  late final TextEditingController _nmbr;
  late final TextEditingController _complement;
  late final TextEditingController _neighborhood;
  late final TextEditingController _zipCode;

  int? _countryId;
  String _countryName = '';
  int? _stateId;
  String _stateName = '';
  int? _cityId;
  String _cityName = '';
  bool _main = true;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _kind         = TextEditingController(text: e?.kind ?? '');
    _street       = TextEditingController(text: e?.street ?? '');
    _nmbr         = TextEditingController(text: e?.nmbr ?? '');
    _complement   = TextEditingController(text: e?.complement ?? '');
    _neighborhood = TextEditingController(text: e?.neighborhood ?? '');
    _zipCode      = TextEditingController(text: e?.zipCode ?? '');
    if (e != null) {
      _countryId   = e.tbCountryId;
      _countryName = e.countryName ?? '';
      _stateId     = e.tbStateId;
      _stateName   = e.stateName ?? '';
      _cityId      = e.tbCityId;
      _cityName    = e.cityName ?? '';
      _main        = e.main;
    }
  }

  @override
  void dispose() {
    for (final c in [_kind, _street, _nmbr, _complement, _neighborhood, _zipCode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showSetesLookup<CountryLookup>(
      context: context,
      title: 'lookup.countries'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.countryLookup.list,
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

  Future<void> _pickState() async {
    final picked = await showSetesLookup<StateLookup>(
      context: context,
      title: 'lookup.states'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.stateLookup.list,
      itemId: (s) => s.id,
      itemLabel: (s) => '${s.abbreviation ?? ''} · ${s.name ?? ''}',
    );
    if (picked != null) {
      setState(() {
        _stateId = picked.id;
        _stateName = picked.name ?? '';
        // UF trocada: a cidade anterior deixa de valer (lookup dependente).
        _cityId = null;
        _cityName = '';
      });
    }
  }

  Future<void> _pickCity() async {
    // Lookup dependente (campo-lookup-fk.md, item 5): exige a UF primeiro.
    final stateId = _stateId;
    if (stateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SetesText('forms.address.stateFirst'.tr())));
      return;
    }
    final picked = await showSetesLookup<CityLookup>(
      context: context,
      title: 'lookup.cities'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: (filter) => widget.cityLookup.list(filter, stateId: stateId),
      itemId: (c) => c.id,
      itemLabel: (c) => c.name ?? '',
    );
    if (picked != null) {
      setState(() {
        _cityId = picked.id;
        _cityName = picked.name ?? '';
      });
    }
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(EntityAddress(
      kind:         _kind.text.trim(),
      street:       _street.text.trim(),
      nmbr:         _nmbr.text.trim().isEmpty ? null : _nmbr.text.trim(),
      complement:   _complement.text.trim().isEmpty ? null : _complement.text.trim(),
      neighborhood: _neighborhood.text.trim().isEmpty ? null : _neighborhood.text.trim(),
      zipCode:      _zipCode.text.trim().isEmpty ? null : _zipCode.text.trim(),
      tbCountryId:  _countryId!,
      tbStateId:    _stateId!,
      tbCityId:     _cityId!,
      main:         _main,
      countryName:  _countryName,
      stateName:    _stateName,
      cityName:     _cityName,
    ));
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                          child: SetesText('forms.address.dialogTitle'.tr(),
                              style: Theme.of(context).textTheme.titleMedium)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, size: 30),
                        onPressed: _confirm,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      SetesTextField(
                        label: 'forms.address.kind'.tr(),
                        controller: _kind,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        validator: kindValidator(widget.takenKinds),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.address.street'.tr(),
                        controller: _street,
                        textInputAction: TextInputAction.next,
                        validator: _validateRequired,
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.address.nmbr'.tr(),
                        controller: _nmbr,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.address.complement'.tr(),
                        controller: _complement,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.address.neighborhood'.tr(),
                        controller: _neighborhood,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.address.zipCode'.tr(),
                        controller: _zipCode,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 16),
                      SetesLookupField(
                        label: 'forms.address.country'.tr(),
                        display: _countryName,
                        onSearch: _pickCountry,
                        validatorMessage: 'register.required'.tr(),
                      ),
                      const SizedBox(height: 16),
                      SetesLookupField(
                        label: 'forms.address.state'.tr(),
                        display: _stateName,
                        onSearch: _pickState,
                        validatorMessage: 'register.required'.tr(),
                      ),
                      const SizedBox(height: 16),
                      SetesLookupField(
                        label: 'forms.address.city'.tr(),
                        display: _cityName,
                        onSearch: _pickCity,
                        validatorMessage: 'register.required'.tr(),
                      ),
                      const SizedBox(height: 8),
                      SetesCheckbox(
                        label: 'forms.address.main'.tr(),
                        value: _main,
                        onChanged: (v) => setState(() => _main = v ?? false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
