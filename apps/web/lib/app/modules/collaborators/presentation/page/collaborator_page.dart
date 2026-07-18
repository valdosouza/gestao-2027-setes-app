import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/data/entity_by_document_datasource.dart';
import '../../../../shared/entity/widgets/address_list_tab.dart';
import '../../../../shared/entity/widgets/entity_main_tab.dart';
import '../../../../shared/entity/widgets/phone_list_tab.dart';
import '../../../../shared/entity/widgets/social_media_list_tab.dart';
import '../../../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/object_collaborator.dart';
import '../bloc/collaborator_bloc.dart';
import '../widget/collaborator_tab.dart';

/// Tela de Colaboradores — interface 'collaborators' (1 interface = 1
/// módulo, ARQUITETURA_MODULOS.md). Onda 2 da Entidade Única (hierarquia de
/// papéis, decisão 16): mesmo desenho do Customer SEM a aba Tributação —
/// form com 5 abas: 4 COMPARTILHADAS (shared/entity/widgets) + a específica
/// CollaboratorTab.
///
/// O bloc guarda o DRAFT do ObjectCollaborator inteiro; as abas editam
/// fatias via onChanged; salvar = 1 evento com o objeto completo. Prefill
/// by-document na CRIAÇÃO; 409 de papel duplicado oferece abrir o registro
/// existente em edição.
class CollaboratorPage extends StatefulWidget {
  const CollaboratorPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<CollaboratorPage> createState() => _CollaboratorPageState();
}

class _CollaboratorPageState extends State<CollaboratorPage> {
  late final CollaboratorBloc _bloc;
  late final CountryLookupDatasource _countryLookup;
  late final StateLookupDatasource _stateLookup;
  late final CityLookupDatasource _cityLookup;
  late final EntityByDocumentDatasource _byDocumentLookup;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CollaboratorBloc>()
      ..add(const CollaboratorListRequested(''));
    _countryLookup = Modular.get<CountryLookupDatasource>();
    _stateLookup = Modular.get<StateLookupDatasource>();
    _cityLookup = Modular.get<CityLookupDatasource>();
    _byDocumentLookup = Modular.get<EntityByDocumentDatasource>();
  }

  Widget _buildSearch(CollaboratorListState state) =>
      RegisterSearchPage<CollaboratorListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'collaborators',
        avatarBuilder: (c) => '${c.id}',
        rowBuilder: (c) => [
          c.nickTrade ?? c.nameCompany ?? '',
          c.nameCompany ?? '',
          c.active
              ? 'forms.collaborator.active'.tr()
              : 'forms.collaborator.inactive'.tr(),
        ],
        onFilterChanged: (filter) =>
            _bloc.add(CollaboratorListRequested(filter)),
        onNew: () => _bloc.add(const CollaboratorNewPressed()),
        onView: (item) => _bloc.add(CollaboratorEditPressed(item.id)),
      );

  Widget _buildForm(CollaboratorFormState state) => _CollaboratorFormView(
        // Troca de registro reinicia abas e controllers.
        key: ValueKey(state.creating
            ? 'collaborator-new'
            : 'collaborator-${state.draft.id}'),
        title: widget.title,
        draft: state.draft,
        creating: state.creating,
        saving: state.saving,
        countryLookup: _countryLookup,
        stateLookup: _stateLookup,
        cityLookup: _cityLookup,
        byDocumentLookup: _byDocumentLookup,
        onDraftChanged: (draft) => _bloc.add(CollaboratorDraftChanged(draft)),
        onSave: () => _bloc.add(CollaboratorSaveRequested(
            draft: state.draft, creating: state.creating)),
        onBack: () => _bloc.add(const CollaboratorBackToListPressed()),
        onDelete: state.creating || state.draft.id == null
            ? null
            : () => _bloc.add(CollaboratorDeleteRequested(state.draft.id!)),
      );

  /// 409 de papel duplicado: oferece abrir o registro existente em edição.
  Future<void> _showDuplicateRoleDialog(int existingId) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('forms.collaborator.duplicateRole'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'forms.collaborator.openEdit'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (open == true) _bloc.add(CollaboratorEditPressed(existingId));
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CollaboratorBloc, CollaboratorBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CollaboratorActionSuccess ||
            current is CollaboratorActionFailure ||
            current is CollaboratorDuplicateRole,
        listener: (context, state) {
          if (state is CollaboratorDuplicateRole) {
            _showDuplicateRoleDialog(state.existingId);
            return;
          }
          final message = state is CollaboratorActionSuccess
              ? state.messageKey.tr()
              : (state as CollaboratorActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is CollaboratorListState ||
            current is CollaboratorFormState,
        builder: (context, state) => switch (state) {
          CollaboratorFormState() => _buildForm(state),
          CollaboratorListState() => _buildSearch(state),
          _ => _buildSearch(const CollaboratorListState(loading: true)),
        },
      );
}

/// Form artesanal com SetesFormShell + TabBar/TabBarView (caso de grupos
/// naturais da criar-formulario-cadastro.md, item 2). O estado do form é o
/// DRAFT no bloc — este widget é apresentação: repassa fatias editadas.
class _CollaboratorFormView extends StatelessWidget {
  const _CollaboratorFormView({
    required this.title,
    required this.draft,
    required this.creating,
    required this.saving,
    required this.countryLookup,
    required this.stateLookup,
    required this.cityLookup,
    required this.byDocumentLookup,
    required this.onDraftChanged,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final ObjectCollaborator draft;
  final bool creating;
  final bool saving;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;
  final EntityByDocumentDatasource byDocumentLookup;
  final ValueChanged<ObjectCollaborator> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
      context).showSnackBar(SnackBar(content: SetesText(message)));

  /// Validação do draft inteiro (as abas podem estar desmontadas — a fonte
  /// de verdade é o draft do bloc). personType 'N' não exige documento.
  void _save(BuildContext context) {
    String? requiredKey;
    if (draft.nameCompany.trim().isEmpty) {
      requiredKey = draft.personType == 'J'
          ? 'forms.entity.nameCompany'
          : 'forms.entity.nameCompanyPerson';
    } else if (draft.nickTrade.trim().isEmpty) {
      requiredKey = draft.personType == 'J'
          ? 'forms.entity.nickTrade'
          : 'forms.entity.nickTradePerson';
    } else if (draft.personType == 'F' &&
        (draft.person?.cpfDigits ?? '').isEmpty) {
      requiredKey = 'forms.entity.cpf';
    } else if (draft.personType == 'J' &&
        (draft.company?.cnpjDigits ?? '').isEmpty) {
      requiredKey = 'forms.entity.cnpj';
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
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'register.tabMain'.tr()),
                  Tab(text: 'register.tabAddresses'.tr()),
                  Tab(text: 'register.tabPhones'.tr()),
                  Tab(text: 'register.tabSocialMedia'.tr()),
                  Tab(text: 'forms.collaborator.tab'.tr()),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    EntityMainTab(
                      value: draft,
                      onChanged: (fiscal) =>
                          onDraftChanged(draft.mergeFiscal(fiscal)),
                      // Prefill by-document só na CRIAÇÃO (decisões 3/9/10)
                      byDocumentLookup: byDocumentLookup,
                      prefillEnabled: creating,
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
                    CollaboratorTab(
                      value: draft,
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
