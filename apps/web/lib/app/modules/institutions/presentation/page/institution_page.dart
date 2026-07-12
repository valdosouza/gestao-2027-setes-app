import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/address_list_tab.dart';
import '../../../../shared/entity/widgets/entity_main_tab.dart';
import '../../../../shared/entity/widgets/phone_list_tab.dart';
import '../../../../shared/entity/widgets/social_media_list_tab.dart';
import '../../../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/object_institution.dart';
import '../bloc/institution_bloc.dart';
import '../widget/institution_tab.dart';

/// Tela de Estabelecimentos — interface 'institutions' (1 interface =
/// 1 módulo, ARQUITETURA_MODULOS.md). Primeiro cadastro com cadeia de
/// entidade fiscal (skill cadastro-entidade-fiscal.md): form com 5 abas —
/// 4 COMPARTILHADAS (shared/entity/widgets) + a específica (InstitutionTab).
/// Acesso: role='super' — sem ACL adicional (decisão 2026-07-09).
///
/// O bloc guarda o DRAFT do ObjectInstitution inteiro; as abas editam
/// fatias via onChanged; salvar = 1 evento com o objeto completo.
class InstitutionPage extends StatefulWidget {
  const InstitutionPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<InstitutionPage> createState() => _InstitutionPageState();
}

class _InstitutionPageState extends State<InstitutionPage> {
  late final InstitutionBloc _bloc;
  late final CountryLookupDatasource _countryLookup;
  late final StateLookupDatasource _stateLookup;
  late final CityLookupDatasource _cityLookup;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<InstitutionBloc>()
      ..add(const InstitutionListRequested(''));
    _countryLookup = Modular.get<CountryLookupDatasource>();
    _stateLookup = Modular.get<StateLookupDatasource>();
    _cityLookup = Modular.get<CityLookupDatasource>();
  }

  Widget _buildSearch(InstitutionListState state) =>
      RegisterSearchPage<InstitutionListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        avatarBuilder: (i) => '${i.id}',
        rowBuilder: (i) => [
          i.nickTrade ?? i.nameCompany ?? '',
          i.schemaName,
          i.active
              ? 'forms.institution.active'.tr()
              : 'forms.institution.inactive'.tr(),
        ],
        onFilterChanged: (filter) =>
            _bloc.add(InstitutionListRequested(filter)),
        onNew: () => _bloc.add(const InstitutionNewPressed()),
        onView: (item) => _bloc.add(InstitutionEditPressed(item.id)),
      );

  Widget _buildForm(InstitutionFormState state) => _InstitutionFormView(
        // Troca de registro reinicia abas e controllers.
        key: ValueKey(
            state.creating ? 'institution-new' : 'institution-${state.draft.id}'),
        title: widget.title,
        draft: state.draft,
        creating: state.creating,
        saving: state.saving,
        countryLookup: _countryLookup,
        stateLookup: _stateLookup,
        cityLookup: _cityLookup,
        onDraftChanged: (draft) => _bloc.add(InstitutionDraftChanged(draft)),
        onSave: () => _bloc.add(InstitutionSaveRequested(
            draft: state.draft, creating: state.creating)),
        onBack: () => _bloc.add(const InstitutionBackToListPressed()),
        onDelete: state.creating || state.draft.id == null
            ? null
            : () => _bloc.add(InstitutionDeleteRequested(state.draft.id!)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<InstitutionBloc, InstitutionBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is InstitutionActionSuccess ||
            current is InstitutionActionFailure,
        listener: (context, state) {
          final message = state is InstitutionActionSuccess
              ? state.messageKey.tr()
              : (state as InstitutionActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is InstitutionListState || current is InstitutionFormState,
        builder: (context, state) => switch (state) {
          InstitutionFormState() => _buildForm(state),
          InstitutionListState() => _buildSearch(state),
          _ => _buildSearch(const InstitutionListState(loading: true)),
        },
      );
}

/// Form artesanal com SetesFormShell + TabBar/TabBarView (caso de grupos
/// naturais da criar-formulario-cadastro.md, item 2). O estado do form é o
/// DRAFT no bloc — este widget é apresentação: repassa fatias editadas.
class _InstitutionFormView extends StatelessWidget {
  const _InstitutionFormView({
    required this.title,
    required this.draft,
    required this.creating,
    required this.saving,
    required this.countryLookup,
    required this.stateLookup,
    required this.cityLookup,
    required this.onDraftChanged,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final ObjectInstitution draft;
  final bool creating;
  final bool saving;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;
  final ValueChanged<ObjectInstitution> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
      context).showSnackBar(SnackBar(content: SetesText(message)));

  /// Validação do draft inteiro (as abas podem estar desmontadas — a fonte
  /// de verdade é o draft do bloc, não os Form das abas).
  void _save(BuildContext context) {
    String? requiredKey;
    if (draft.nameCompany.trim().isEmpty) {
      requiredKey = 'forms.entity.nameCompany';
    } else if (draft.nickTrade.trim().isEmpty) {
      requiredKey = 'forms.entity.nickTrade';
    } else if (draft.personType == 'F' &&
        (draft.person?.cpfDigits ?? '').isEmpty) {
      requiredKey = 'forms.entity.cpf';
    } else if (draft.personType == 'J' &&
        (draft.company?.cnpjDigits ?? '').isEmpty) {
      requiredKey = 'forms.entity.cnpj';
    } else if (creating && draft.schemaName.trim().isEmpty) {
      requiredKey = 'forms.institution.schemaName';
    }
    if (requiredKey != null) {
      _snack(context, 'register.requiredField'.tr(args: [requiredKey.tr()]));
      return;
    }
    if (draft.personType == 'F' && draft.person!.cpfDigits.length != 11) {
      _snack(context, 'forms.entity.cpfInvalid'.tr());
      return;
    }
    if (draft.personType == 'J' && draft.company!.cnpjDigits.length != 14) {
      _snack(context, 'forms.entity.cnpjInvalid'.tr());
      return;
    }
    if (creating &&
        !RegExp(r'^setes_[a-z0-9_]+$').hasMatch(draft.schemaName.trim())) {
      _snack(context, 'forms.institution.schemaNameInvalid'.tr());
      return;
    }
    onSave();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('register.confirmDelete'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'register.delete'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) => SetesFormShell(
        title: title,
        saving: saving,
        onBack: onBack,
        onSave: () => _save(context),
        onDelete: onDelete != null ? () => _confirmDelete(context) : null,
        child: DefaultTabController(
          length: 5,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: 'register.tabMain'.tr()),
                  Tab(text: 'register.tabAddresses'.tr()),
                  Tab(text: 'register.tabPhones'.tr()),
                  Tab(text: 'register.tabSocialMedia'.tr()),
                  Tab(text: 'forms.institution.tab'.tr()),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    EntityMainTab(
                      value: draft,
                      onChanged: (fiscal) =>
                          onDraftChanged(draft.mergeFiscal(fiscal)),
                    ),
                    AddressListTab(
                      items: draft.addresses,
                      countryLookup: countryLookup,
                      stateLookup: stateLookup,
                      cityLookup: cityLookup,
                      onChanged: (list) =>
                          onDraftChanged(draft.copyWith(addresses: list)),
                    ),
                    PhoneListTab(
                      items: draft.phones,
                      onChanged: (list) =>
                          onDraftChanged(draft.copyWith(phones: list)),
                    ),
                    SocialMediaListTab(
                      items: draft.socialMedia,
                      onChanged: (list) =>
                          onDraftChanged(draft.copyWith(socialMedia: list)),
                    ),
                    InstitutionTab(
                      value: draft,
                      creating: creating,
                      onChanged: onDraftChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
