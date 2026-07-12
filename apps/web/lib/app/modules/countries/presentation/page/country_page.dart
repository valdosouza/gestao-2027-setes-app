import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/country_entity.dart';
import '../bloc/country_bloc.dart';

/// Tela de Países — interface 'countries' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Pesquisa ↔ formulário orquestrados pelo
/// CountryBloc; a página só traduz estados em widgets da fábrica.
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// Código do país = padrão mundial BACEN (Brasil 1058), informado na
/// inclusão e imutável na edição (decisão do Valdo 2026-07-10).
class CountryPage extends StatefulWidget {
  const CountryPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<CountryPage> createState() => _CountryPageState();
}

class _CountryPageState extends State<CountryPage> with FieldConfigLoader {
  late final CountryBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CountryBloc>()..add(const CountryListRequested(''));
    loadFieldConfig('countries'); // engine de campos configuráveis (decisão 7)
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

  Widget _buildForm(CountryFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    return RegisterFormPage(
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {'id': '${editing.id}', 'name': editing.name ?? ''},
      fields: applyFieldConfig([
        RegisterField(
          name:         'id',
          label:        'forms.country.code'.tr(),
          keyboardType: TextInputType.number,
          readOnly:     !creating, // código BACEN imutável na edição
          validator:    creating ? _validateCode : null,
        ),
        RegisterField(
          name:      'name',
          label:     'forms.country.name'.tr(),
          validator: _validateRequired,
        ),
      ], fieldConfig),
      onSave: (values) => _bloc.add(CountrySaveRequested(
        country: CountryEntity(
          id:   int.parse(values['id']!),
          name: values['name'] ?? '',
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const CountryBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(CountryDeleteRequested(editing.id)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(CountryListState state) => RegisterSearchPage<CountryEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        avatarBuilder: (c) => '${c.id}',
        rowBuilder: (c) => [c.name ?? ''],
        onFilterChanged: (filter) => _bloc.add(CountryListRequested(filter)),
        onNew: () => _bloc.add(const CountryNewPressed()),
        onView: (c) => _bloc.add(CountryEditPressed(c)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CountryBloc, CountryState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CountryActionSuccess || current is CountryActionFailure,
        listener: (context, state) {
          final message = state is CountryActionSuccess
              ? state.messageKey.tr()
              : (state as CountryActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is CountryListState || current is CountryFormState,
        builder: (context, state) => switch (state) {
          CountryFormState() => _buildForm(state),
          CountryListState() => _buildSearch(state),
          _ => _buildSearch(const CountryListState(loading: true)),
        },
      );
}
