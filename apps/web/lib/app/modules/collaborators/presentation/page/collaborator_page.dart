import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/data/entity_by_document_datasource.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
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

  /// Acesso ao form montado: ancora o fields[] do servidor no campo da aba
  /// certa (showServerFieldError — Framework de Mensagens, Onda B). Na
  /// lista o currentState é null.
  final _formViewKey = GlobalKey<_CollaboratorFormViewState>();

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
        key: _formViewKey,
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

  /// 409 de papel duplicado (code DUP_ROLE do catálogo) é uma DECISÃO
  /// tipada via ponte (R4): Sim = abrir o registro existente em edição;
  /// Cancelar (ou fechar) = permanecer no form.
  Future<void> _askDuplicateRole(int existingId) async {
    final decision = await askDecision(
      context,
      message: 'forms.collaborator.duplicateRole'.tr(),
      yesLabel: 'forms.collaborator.openEdit'.tr(),
    );
    if (decision == SetesDecision.yes && mounted) {
      _bloc.add(CollaboratorEditPressed(existingId));
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CollaboratorBloc, CollaboratorBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CollaboratorActionSuccess ||
            current is CollaboratorActionFailure ||
            current is CollaboratorDuplicateRole,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo (aba
        // certa + foco) quando o form está montado; DUP_ROLE = decisão (R4).
        listener: (context, state) {
          if (state is CollaboratorDuplicateRole) {
            _askDuplicateRole(state.existingId);
            return;
          }
          if (state is CollaboratorActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as CollaboratorActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
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
///
/// Stateful pelo Framework de Mensagens (Onda B): o TabController próprio
/// permite à mecânica uma-pendência (R3) e ao fields[] do servidor TROCAR
/// para a aba do campo antes do foco (beforeFocus dos PendencyFields).
class _CollaboratorFormView extends StatefulWidget {
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

  @override
  State<_CollaboratorFormView> createState() => _CollaboratorFormViewState();
}

class _CollaboratorFormViewState extends State<_CollaboratorFormView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  /// Ganchos de foco/marcação dos campos da aba Principal (R3).
  final _mainHooks = EntityMainTabHooks();

  @override
  void dispose() {
    _tabs.dispose();
    _mainHooks.dispose();
    super.dispose();
  }

  ObjectCollaborator get _draft => widget.draft;

  /// Validação do draft inteiro (as abas podem estar desmontadas — a fonte
  /// de verdade é o draft do bloc), NA ORDEM das abas e dos campos na tela
  /// (R3). personType 'N' não exige documento. Os names casam com o payload
  /// da API — por eles o fields[] do servidor ancora no campo, trocando
  /// para a aba certa antes do foco.
  List<PendencyField> get _pendencyFields {
    void toMainTab() => _tabs.animateTo(0);
    final isCompany = _draft.personType == 'J';
    return [
      PendencyField(
        name: 'nameCompany',
        beforeFocus: toMainTab,
        focusNode: _mainHooks.nameCompanyFocus,
        fieldKey: _mainHooks.nameCompanyKey,
        validate: () => _draft.nameCompany.trim().isEmpty
            ? 'register.requiredField'.tr(args: [
                (isCompany
                        ? 'forms.entity.nameCompany'
                        : 'forms.entity.nameCompanyPerson')
                    .tr()
              ])
            : null,
      ),
      PendencyField(
        name: 'nickTrade',
        beforeFocus: toMainTab,
        focusNode: _mainHooks.nickTradeFocus,
        fieldKey: _mainHooks.nickTradeKey,
        validate: () => _draft.nickTrade.trim().isEmpty
            ? 'register.requiredField'.tr(args: [
                (isCompany
                        ? 'forms.entity.nickTrade'
                        : 'forms.entity.nickTradePerson')
                    .tr()
              ])
            : null,
      ),
      if (_draft.personType == 'F')
        PendencyField(
          name: 'cpf',
          beforeFocus: toMainTab,
          focusNode: _mainHooks.cpfFocus,
          fieldKey: _mainHooks.cpfKey,
          validate: () {
            final digits = _draft.person?.cpfDigits ?? '';
            if (digits.isEmpty) {
              return 'register.requiredField'
                  .tr(args: ['forms.entity.cpf'.tr()]);
            }
            if (digits.length != 11) return 'forms.entity.cpfInvalid'.tr();
            return null;
          },
        ),
      if (_draft.personType == 'J')
        PendencyField(
          name: 'cnpj',
          beforeFocus: toMainTab,
          focusNode: _mainHooks.cnpjFocus,
          fieldKey: _mainHooks.cnpjKey,
          validate: () {
            final digits = _draft.company?.cnpjDigits ?? '';
            if (digits.isEmpty) {
              return 'register.requiredField'
                  .tr(args: ['forms.entity.cnpj'.tr()]);
            }
            if (digits.length != 14) return 'forms.entity.cnpjInvalid'.tr();
            return null;
          },
        ),
    ];
  }

  /// Ancora o fields[] do envelope 400/409 no campo — aba certa + foco
  /// (chamado pelo listener do bloc via GlobalKey).
  Future<void> showServerFieldError(Failure failure) =>
      showServerFieldFeedback(context, failure, _pendencyFields);

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    widget.onSave();
  }

  /// Exclusão confirmada via decisão TIPADA da ponte (R4): Sim = excluir;
  /// Cancelar (ou fechar) = nada. Sem ação alternativa → sem botão Não.
  Future<void> _confirmDelete() async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return SetesFormShell(
      title: widget.title,
      saving: widget.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      // Troca de registro reinicia abas e controllers (o form fica montado
      // no fluxo DUP_ROLE → abrir em edição).
      child: KeyedSubtree(
        key: ValueKey(widget.creating
            ? 'collaborator-new'
            : 'collaborator-${draft.id}'),
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
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
                controller: _tabs,
                children: [
                  EntityMainTab(
                    value: draft,
                    onChanged: (fiscal) =>
                        widget.onDraftChanged(draft.mergeFiscal(fiscal)),
                    // Prefill by-document só na CRIAÇÃO (decisões 3/9/10)
                    byDocumentLookup: widget.byDocumentLookup,
                    prefillEnabled: widget.creating,
                    hooks: _mainHooks,
                  ),
                  AddressListTab(
                    items: draft.addresses,
                    countryLookup: widget.countryLookup,
                    stateLookup: widget.stateLookup,
                    cityLookup: widget.cityLookup,
                    onChanged: (list) => widget
                        .onDraftChanged(draft.copyWith(addresses: list)),
                  ),
                  PhoneListTab(
                    items: draft.phones,
                    onChanged: (list) =>
                        widget.onDraftChanged(draft.copyWith(phones: list)),
                  ),
                  SocialMediaListTab(
                    items: draft.socialMedia,
                    onChanged: (list) => widget
                        .onDraftChanged(draft.copyWith(socialMedia: list)),
                  ),
                  CollaboratorTab(
                    value: draft,
                    onChanged: widget.onDraftChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
