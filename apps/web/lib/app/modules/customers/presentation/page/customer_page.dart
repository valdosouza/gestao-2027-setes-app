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
import '../../../../shared/lookup/datasource/carrier_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../../../shared/interface_config/interface_config_loader.dart';
import '../../../../shared/lookup/datasource/salesman_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/session_context.dart';
import '../../data/datasource/customer_partnership_datasource.dart';
import '../../domain/entity/object_customer.dart';
import '../bloc/customer_bloc.dart';
import '../widget/customer_partnership_tab.dart';
import '../widget/customer_tab.dart';
import '../widget/customer_tax_tab.dart';

/// Tela de Clientes — interface 'customers' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Primeiro papel novo da Fase 3 Entidade Única:
/// form com 7 abas — 4 COMPARTILHADAS (shared/entity/widgets) + as
/// específicas CustomerTab (decisão 11), CustomerTaxTab (Rodada 4 —
/// Tributação, tb_entity_tax) e CustomerPartnershipTab (Parceria v2 —
/// angariação, aba autônoma via GET/PUT /api/customers/:id/partnership).
///
/// O bloc guarda o DRAFT do ObjectCustomer inteiro; as abas editam fatias
/// via onChanged; salvar = 1 evento com o objeto completo. Prefill
/// by-document na CRIAÇÃO (decisões 3, 9 e 10); 409 de papel duplicado
/// oferece abrir o registro existente em edição (decisão 2).
class CustomerPage extends StatefulWidget {
  const CustomerPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage>
    with InterfaceConfigLoader {
  late final CustomerBloc _bloc;
  late final CountryLookupDatasource _countryLookup;
  late final StateLookupDatasource _stateLookup;
  late final CityLookupDatasource _cityLookup;
  late final SalesmanLookupDatasource _salesmanLookup;
  late final CarrierLookupDatasource _carrierLookup;
  late final EntityByDocumentDatasource _byDocumentLookup;
  late final CustomerPartnershipDatasource _partnershipDatasource;

  /// Acesso ao form montado: ancora o fields[] do servidor no campo da aba
  /// certa (showServerFieldError — Framework de Mensagens, Onda B). Na
  /// lista o currentState é null.
  final _formViewKey = GlobalKey<_CustomerFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CustomerBloc>()..add(const CustomerListRequested(''));
    _countryLookup = Modular.get<CountryLookupDatasource>();
    _stateLookup = Modular.get<StateLookupDatasource>();
    _cityLookup = Modular.get<CityLookupDatasource>();
    _salesmanLookup = Modular.get<SalesmanLookupDatasource>();
    _carrierLookup = Modular.get<CarrierLookupDatasource>();
    _byDocumentLookup = Modular.get<EntityByDocumentDatasource>();
    _partnershipDatasource = Modular.get<CustomerPartnershipDatasource>();
    // Engine do Framework de Configurações (piloto — decisões 10, 14 e 15)
    loadInterfaceConfig('customers');
  }

  /// Filtro de carteira (decisão 15): config ligada + usuário-vendedor →
  /// a API já devolve só a carteira; aqui o filtro aparece FIXO e BLOQUEADO
  /// (banner informativo — UX apenas, enforcement na API).
  bool get _walletLocked =>
      configBool('restrict_customer_to_salesman') &&
      Modular.get<SessionContext>().isSalesman;

  /// Pré-seleções do cadastro novo (decisões 10 e 14): predominância
  /// PF/PJ e Consumidor('C'→'S')/Revenda('R'→'N') da aba Tributação.
  void _newCustomer() {
    final personType = configContent('default_person_type');
    final customerKind = configContent('default_customer_kind');
    _bloc.add(CustomerNewPressed(
      personType: personType.isEmpty ? null : personType,
      consumer: switch (customerKind) {
        'C' => 'S',
        'R' => 'N',
        _ => null,
      },
    ));
  }

  Widget _buildSearch(CustomerListState state) =>
      RegisterSearchPage<CustomerListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        // Engrenagem padrão da lista (decisão 11) — painel já filtrado
        configModuleKey: 'customers',
        banner: _walletLocked
            ? Row(children: [
                const Icon(Icons.lock_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: SetesText('forms.customer.walletLocked'.tr())),
              ])
            : null,
        avatarBuilder: (c) => '${c.id}',
        rowBuilder: (c) => [
          c.nickTrade ?? c.nameCompany ?? '',
          c.nameCompany ?? '',
          c.active
              ? 'forms.customer.active'.tr()
              : 'forms.customer.inactive'.tr(),
        ],
        onFilterChanged: (filter) => _bloc.add(CustomerListRequested(filter)),
        onNew: _newCustomer,
        onView: (item) => _bloc.add(CustomerEditPressed(item.id)),
      );

  Widget _buildForm(CustomerFormState state) => _CustomerFormView(
        key: _formViewKey,
        title: widget.title,
        draft: state.draft,
        creating: state.creating,
        saving: state.saving,
        countryLookup: _countryLookup,
        stateLookup: _stateLookup,
        cityLookup: _cityLookup,
        salesmanLookup: _salesmanLookup,
        carrierLookup: _carrierLookup,
        byDocumentLookup: _byDocumentLookup,
        partnershipDatasource: _partnershipDatasource,
        onDraftChanged: (draft) => _bloc.add(CustomerDraftChanged(draft)),
        onSave: () => _bloc.add(CustomerSaveRequested(
            draft: state.draft, creating: state.creating)),
        onBack: () => _bloc.add(const CustomerBackToListPressed()),
        onDelete: state.creating || state.draft.id == null
            ? null
            : () => _bloc.add(CustomerDeleteRequested(state.draft.id!)),
      );

  /// 409 de papel duplicado (Fase 3, decisão 2; code DUP_ROLE do catálogo)
  /// é uma DECISÃO tipada via ponte (R4): Sim = abrir o registro existente
  /// em edição; Cancelar (ou fechar) = permanecer no form.
  Future<void> _askDuplicateRole(int existingId) async {
    final decision = await askDecision(
      context,
      message: 'forms.customer.duplicateRole'.tr(),
      yesLabel: 'forms.customer.openEdit'.tr(),
    );
    if (decision == SetesDecision.yes && mounted) {
      _bloc.add(CustomerEditPressed(existingId));
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CustomerBloc, CustomerBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CustomerActionSuccess ||
            current is CustomerActionFailure ||
            current is CustomerDuplicateRole,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo (aba
        // certa + foco) quando o form está montado; DUP_ROLE = decisão (R4).
        listener: (context, state) {
          if (state is CustomerDuplicateRole) {
            _askDuplicateRole(state.existingId);
            return;
          }
          if (state is CustomerActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as CustomerActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is CustomerListState || current is CustomerFormState,
        builder: (context, state) => switch (state) {
          CustomerFormState() => _buildForm(state),
          CustomerListState() => _buildSearch(state),
          _ => _buildSearch(const CustomerListState(loading: true)),
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
class _CustomerFormView extends StatefulWidget {
  const _CustomerFormView({
    required this.title,
    required this.draft,
    required this.creating,
    required this.saving,
    required this.countryLookup,
    required this.stateLookup,
    required this.cityLookup,
    required this.salesmanLookup,
    required this.carrierLookup,
    required this.byDocumentLookup,
    required this.partnershipDatasource,
    required this.onDraftChanged,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final ObjectCustomer draft;
  final bool creating;
  final bool saving;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;
  final SalesmanLookupDatasource salesmanLookup;
  final CarrierLookupDatasource carrierLookup;
  final EntityByDocumentDatasource byDocumentLookup;
  final CustomerPartnershipDatasource partnershipDatasource;
  final ValueChanged<ObjectCustomer> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_CustomerFormView> createState() => _CustomerFormViewState();
}

class _CustomerFormViewState extends State<_CustomerFormView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);

  /// Ganchos de foco/marcação dos campos da aba Principal (R3).
  final _mainHooks = EntityMainTabHooks();

  @override
  void dispose() {
    _tabs.dispose();
    _mainHooks.dispose();
    super.dispose();
  }

  ObjectCustomer get _draft => widget.draft;

  /// Validação do draft inteiro (as abas podem estar desmontadas — a fonte
  /// de verdade é o draft do bloc, não os Form das abas), NA ORDEM das abas
  /// e dos campos na tela (R3). personType 'N' não exige documento (Fase 3,
  /// decisão 4). Os names casam com o payload da API — por eles o fields[]
  /// do servidor ancora no campo, trocando para a aba certa antes do foco.
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
    final creating = widget.creating;
    return SetesFormShell(
      title: widget.title,
      saving: widget.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      // Troca de registro reinicia abas e controllers (o form fica montado
      // no fluxo DUP_ROLE → abrir em edição).
      child: KeyedSubtree(
        key: ValueKey(creating ? 'customer-new' : 'customer-${draft.id}'),
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
                Tab(text: 'forms.customer.tab'.tr()),
                Tab(text: 'forms.customer.tax.tab'.tr()),
                Tab(text: 'forms.customer.tabPartnership'.tr()),
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
                  CustomerTab(
                    value: draft,
                    onChanged: widget.onDraftChanged,
                    salesmanLookup: widget.salesmanLookup,
                    carrierLookup: widget.carrierLookup,
                  ),
                  // Rodada 4: aba Tributação edita a fatia `tax` do draft
                  // (o form SEMPRE envia — toJson usa default se null)
                  CustomerTaxTab(
                    value: draft.tax ?? const EntityTaxData(),
                    onChanged: (tax) =>
                        widget.onDraftChanged(draft.copyWith(tax: tax)),
                  ),
                  // Parceria v2 (angariação): aba AUTÔNOMA — CRUD próprio
                  // via GET/PUT /api/customers/:id/partnership, fora do
                  // draft do bloc (só na edição).
                  CustomerPartnershipTab(
                    customerId: creating ? null : draft.id,
                    datasource: widget.partnershipDatasource,
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
