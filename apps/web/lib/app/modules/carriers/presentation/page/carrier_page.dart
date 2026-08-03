import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/data/entity_by_document_datasource.dart';
import '../../../../shared/entity/domain/entity_tax.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/entity/widgets/address_list_tab.dart';
import '../../../../shared/entity/widgets/entity_main_tab.dart';
import '../../../../shared/entity/widgets/entity_tax_tab.dart';
import '../../../../shared/entity/widgets/phone_list_tab.dart';
import '../../../../shared/entity/widgets/social_media_list_tab.dart';
import '../../../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../domain/entity/object_carrier.dart';
import '../bloc/carrier_bloc.dart';
import '../widget/carrier_tab.dart';

/// Tela de Transportadoras — interface 'carriers' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Onda 2 da Entidade Única
/// (prompt_onda2_salesman_carrier.md): molde collaborator + a aba
/// Tributação COMPARTILHADA (D2) — form com 6 abas: 5 COMPARTILHADAS
/// (shared/entity/widgets, incluindo EntityTaxTab) + a específica
/// CarrierTab.
///
/// O bloc guarda o DRAFT do ObjectCarrier inteiro; as abas editam fatias
/// via onChanged; salvar = 1 evento com o objeto completo. Prefill
/// by-document na CRIAÇÃO; 409 de papel duplicado oferece abrir o registro
/// existente em edição.
class CarrierPage extends StatefulWidget {
  const CarrierPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<CarrierPage> createState() => _CarrierPageState();
}

class _CarrierPageState extends State<CarrierPage> {
  late final CarrierBloc _bloc;
  late final CountryLookupDatasource _countryLookup;
  late final StateLookupDatasource _stateLookup;
  late final CityLookupDatasource _cityLookup;
  late final EntityByDocumentDatasource _byDocumentLookup;

  /// Acesso ao form montado: ancora o fields[] do servidor no campo da aba
  /// certa (showServerFieldError — Framework de Mensagens, Onda B). Na
  /// lista o currentState é null.
  final _formViewKey = GlobalKey<_CarrierFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CarrierBloc>()..add(const CarrierListRequested(''));
    _countryLookup = Modular.get<CountryLookupDatasource>();
    _stateLookup = Modular.get<StateLookupDatasource>();
    _cityLookup = Modular.get<CityLookupDatasource>();
    _byDocumentLookup = Modular.get<EntityByDocumentDatasource>();
  }

  Widget _buildSearch(CarrierListState state) =>
      RegisterSearchPage<CarrierListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'carriers',
        avatarBuilder: (c) => '${c.id}',
        rowBuilder: (c) => [
          c.nickTrade ?? c.nameCompany ?? '',
          c.nameCompany ?? '',
          c.active
              ? 'forms.carrier.active'.tr()
              : 'forms.carrier.inactive'.tr(),
        ],
        // Paginação (D1/D3): metadados do estado montam a barra da fábrica;
        // filtro novo volta à página 1; troca de tamanho recarrega na 1
        // (a persistência da escolha é da fábrica — D4).
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(CarrierListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(CarrierListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) => _bloc.add(CarrierListRequested(filter)),
        onNew: () => _bloc.add(const CarrierNewPressed()),
        onView: (item) => _bloc.add(CarrierEditPressed(item.id)),
      );

  Widget _buildForm(CarrierFormState state) => _CarrierFormView(
        key: _formViewKey,
        title: widget.title,
        draft: state.draft,
        creating: state.creating,
        saving: state.saving,
        countryLookup: _countryLookup,
        stateLookup: _stateLookup,
        cityLookup: _cityLookup,
        byDocumentLookup: _byDocumentLookup,
        onDraftChanged: (draft) => _bloc.add(CarrierDraftChanged(draft)),
        onSave: () => _bloc.add(CarrierSaveRequested(
            draft: state.draft, creating: state.creating)),
        onBack: () => _bloc.add(const CarrierBackToListPressed()),
        onDelete: state.creating || state.draft.id == null
            ? null
            : () => _bloc.add(CarrierDeleteRequested(state.draft.id!)),
      );

  /// 409 de papel duplicado (code DUP_ROLE do catálogo) é uma DECISÃO
  /// tipada via ponte (R4): Sim = abrir o registro existente em edição;
  /// Cancelar (ou fechar) = permanecer no form.
  Future<void> _askDuplicateRole(int existingId) async {
    final decision = await askDecision(
      context,
      message: 'forms.carrier.duplicateRole'.tr(),
      yesLabel: 'forms.carrier.openEdit'.tr(),
    );
    if (decision == SetesDecision.yes && mounted) {
      _bloc.add(CarrierEditPressed(existingId));
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CarrierBloc, CarrierBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CarrierActionSuccess ||
            current is CarrierActionFailure ||
            current is CarrierDuplicateRole,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo (aba
        // certa + foco) quando o form está montado; DUP_ROLE = decisão (R4).
        listener: (context, state) {
          if (state is CarrierDuplicateRole) {
            _askDuplicateRole(state.existingId);
            return;
          }
          if (state is CarrierActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as CarrierActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is CarrierListState || current is CarrierFormState,
        builder: (context, state) => switch (state) {
          CarrierFormState() => _buildForm(state),
          CarrierListState() => _buildSearch(state),
          _ => _buildSearch(const CarrierListState(loading: true)),
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
class _CarrierFormView extends StatefulWidget {
  const _CarrierFormView({
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
  final ObjectCarrier draft;
  final bool creating;
  final bool saving;
  final CountryLookupDatasource countryLookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;
  final EntityByDocumentDatasource byDocumentLookup;
  final ValueChanged<ObjectCarrier> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_CarrierFormView> createState() => _CarrierFormViewState();
}

class _CarrierFormViewState extends State<_CarrierFormView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  /// Ganchos de foco/marcação dos campos da aba Principal (R3).
  final _mainHooks = EntityMainTabHooks();

  @override
  void dispose() {
    _tabs.dispose();
    _mainHooks.dispose();
    super.dispose();
  }

  ObjectCarrier get _draft => widget.draft;

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
        key: ValueKey(
            widget.creating ? 'carrier-new' : 'carrier-${draft.id}'),
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
                Tab(text: 'forms.carrier.tab'.tr()),
                Tab(text: 'forms.entityTax.tab'.tr()),
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
                  CarrierTab(
                    value: draft,
                    onChanged: widget.onDraftChanged,
                  ),
                  // Aba Tributação COMPARTILHADA (D2): edita a fatia `tax`
                  // do draft (o form SEMPRE envia — toJson usa default)
                  EntityTaxTab(
                    value: draft.tax ?? const EntityTaxData(),
                    onChanged: (tax) =>
                        widget.onDraftChanged(draft.copyWith(tax: tax)),
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
