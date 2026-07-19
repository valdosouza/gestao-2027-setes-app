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
import '../../../../shared/users/datasource/user_datasource.dart';
import '../../data/datasource/institution_datasource.dart';
import '../../domain/entity/object_institution.dart';
import '../bloc/institution_bloc.dart';
import '../widget/institution_interfaces_tab.dart';
import '../widget/institution_tab.dart';
import '../widget/institution_users_tab.dart';

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
  late final InstitutionDatasource _datasource;
  late final UserDatasource _userDatasource;
  late final CountryLookupDatasource _countryLookup;
  late final StateLookupDatasource _stateLookup;
  late final CityLookupDatasource _cityLookup;
  late final EntityByDocumentDatasource _byDocumentLookup;

  /// Acesso ao form montado: ancora o fields[] do servidor no campo da aba
  /// certa (showServerFieldError — Framework de Mensagens, Onda B). Na
  /// lista o currentState é null.
  final _formViewKey = GlobalKey<_InstitutionFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<InstitutionBloc>()
      ..add(const InstitutionListRequested(''));
    // Abas Interfaces (contrato) e Usuários: CRUD autônomo via datasource,
    // fora do draft do bloc (precedente dos privilégios da tela Interfaces).
    _datasource = Modular.get<InstitutionDatasource>();
    _userDatasource = Modular.get<UserDatasource>();
    _countryLookup = Modular.get<CountryLookupDatasource>();
    _stateLookup = Modular.get<StateLookupDatasource>();
    _cityLookup = Modular.get<CityLookupDatasource>();
    _byDocumentLookup = Modular.get<EntityByDocumentDatasource>();
  }

  Widget _buildSearch(InstitutionListState state) =>
      RegisterSearchPage<InstitutionListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'institutions',
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
        key: _formViewKey,
        title: widget.title,
        draft: state.draft,
        creating: state.creating,
        saving: state.saving,
        datasource: _datasource,
        userDatasource: _userDatasource,
        countryLookup: _countryLookup,
        stateLookup: _stateLookup,
        cityLookup: _cityLookup,
        byDocumentLookup: _byDocumentLookup,
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
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo (aba
        // certa + foco) quando o form está montado.
        listener: (context, state) {
          if (state is InstitutionActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as InstitutionActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
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
///
/// Stateful pelo Framework de Mensagens (Onda B): o TabController próprio
/// permite à mecânica uma-pendência (R3) e ao fields[] do servidor TROCAR
/// para a aba do campo antes do foco (beforeFocus dos PendencyFields).
class _InstitutionFormView extends StatefulWidget {
  const _InstitutionFormView({
    required this.title,
    required this.draft,
    required this.creating,
    required this.saving,
    required this.datasource,
    required this.userDatasource,
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
  final ObjectInstitution draft;
  final bool creating;
  final bool saving;
  final InstitutionDatasource datasource;
  final UserDatasource userDatasource;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;
  final EntityByDocumentDatasource byDocumentLookup;
  final ValueChanged<ObjectInstitution> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_InstitutionFormView> createState() => _InstitutionFormViewState();
}

class _InstitutionFormViewState extends State<_InstitutionFormView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);

  /// Ganchos de foco/marcação dos campos da aba Principal (R3) e do
  /// schemaName da aba Estabelecimento.
  final _mainHooks = EntityMainTabHooks();
  final _schemaNameFocus = FocusNode();
  final _schemaNameKey = GlobalKey<FormFieldState<String>>();

  @override
  void dispose() {
    _tabs.dispose();
    _mainHooks.dispose();
    _schemaNameFocus.dispose();
    super.dispose();
  }

  ObjectInstitution get _draft => widget.draft;

  /// Validação do draft inteiro (as abas podem estar desmontadas — a fonte
  /// de verdade é o draft do bloc), NA ORDEM das abas e dos campos na tela
  /// (R3): aba Principal primeiro, depois o schemaName da aba
  /// Estabelecimento (só na inclusão). Os names casam com o payload da API
  /// — por eles o fields[] do servidor ancora no campo, trocando para a aba
  /// certa antes do foco.
  List<PendencyField> get _pendencyFields {
    void toMainTab() => _tabs.animateTo(0);
    void toInstitutionTab() => _tabs.animateTo(4);
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
      if (widget.creating)
        PendencyField(
          name: 'schemaName',
          beforeFocus: toInstitutionTab,
          focusNode: _schemaNameFocus,
          fieldKey: _schemaNameKey,
          validate: () {
            final text = _draft.schemaName.trim();
            if (text.isEmpty) {
              return 'register.requiredField'
                  .tr(args: ['forms.institution.schemaName'.tr()]);
            }
            if (!RegExp(r'^setes_[a-z0-9_]+$').hasMatch(text)) {
              return 'forms.institution.schemaNameInvalid'.tr();
            }
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
    final creating = widget.creating;
    return SetesFormShell(
      title: widget.title,
      saving: widget.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      // Troca de registro reinicia abas e controllers.
      child: KeyedSubtree(
        key: ValueKey(
            creating ? 'institution-new' : 'institution-${draft.id}'),
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: 'register.tabMain'.tr()),
                Tab(text: 'register.tabAddresses'.tr()),
                Tab(text: 'register.tabPhones'.tr()),
                Tab(text: 'register.tabSocialMedia'.tr()),
                Tab(text: 'forms.institution.tab'.tr()),
                Tab(text: 'forms.institution.tabInterfaces'.tr()),
                Tab(text: 'forms.institution.tabUsers'.tr()),
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
                    // Prefill by-document só na CRIAÇÃO (Fase 3, dec. 3/9/10)
                    byDocumentLookup: widget.byDocumentLookup,
                    prefillEnabled: creating,
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
                  InstitutionTab(
                    value: draft,
                    creating: creating,
                    onChanged: widget.onDraftChanged,
                    schemaNameFocus: _schemaNameFocus,
                    schemaNameKey: _schemaNameKey,
                  ),
                  // Contrato comercial de interfaces — CRUD autônomo
                  // (sincroniza a cada toggle; só na edição).
                  InstitutionInterfacesTab(
                    institutionId: creating ? null : draft.id,
                    datasource: widget.datasource,
                  ),
                  // Usuários do institution (workflow 2026-07-12): lista
                  // filtrada + botão + com o institution IMPLÍCITO —
                  // facilita liberar o primeiro admin do cliente.
                  InstitutionUsersTab(
                    institutionId: creating ? null : draft.id,
                    datasource: widget.userDatasource,
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
