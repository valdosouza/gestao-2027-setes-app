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
import '../../../../shared/lookup/datasource/carrier_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/country_lookup_datasource.dart';
import '../../../../shared/interface_config/interface_config_loader.dart';
import '../../../../shared/lookup/datasource/salesman_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/session_context.dart';
import '../../domain/entity/object_customer.dart';
import '../bloc/customer_bloc.dart';
import '../widget/customer_tab.dart';
import '../widget/customer_tax_tab.dart';

/// Tela de Clientes — interface 'customers' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Primeiro papel novo da Fase 3 Entidade Única:
/// form com 6 abas — 4 COMPARTILHADAS (shared/entity/widgets) + as
/// específicas CustomerTab (decisão 11) e CustomerTaxTab (Rodada 4 —
/// Tributação, tb_entity_tax).
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
        // Troca de registro reinicia abas e controllers.
        key: ValueKey(
            state.creating ? 'customer-new' : 'customer-${state.draft.id}'),
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
        onDraftChanged: (draft) => _bloc.add(CustomerDraftChanged(draft)),
        onSave: () => _bloc.add(CustomerSaveRequested(
            draft: state.draft, creating: state.creating)),
        onBack: () => _bloc.add(const CustomerBackToListPressed()),
        onDelete: state.creating || state.draft.id == null
            ? null
            : () => _bloc.add(CustomerDeleteRequested(state.draft.id!)),
      );

  /// 409 de papel duplicado (Fase 3, decisão 2): oferece abrir o registro
  /// existente em edição.
  Future<void> _showDuplicateRoleDialog(int existingId) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('forms.customer.duplicateRole'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'forms.customer.openEdit'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (open == true) _bloc.add(CustomerEditPressed(existingId));
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CustomerBloc, CustomerBlocState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CustomerActionSuccess ||
            current is CustomerActionFailure ||
            current is CustomerDuplicateRole,
        listener: (context, state) {
          if (state is CustomerDuplicateRole) {
            _showDuplicateRoleDialog(state.existingId);
            return;
          }
          final message = state is CustomerActionSuccess
              ? state.messageKey.tr()
              : (state as CustomerActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
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
class _CustomerFormView extends StatelessWidget {
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
  final ValueChanged<ObjectCustomer> onDraftChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
      context).showSnackBar(SnackBar(content: SetesText(message)));

  /// Validação do draft inteiro (as abas podem estar desmontadas — a fonte
  /// de verdade é o draft do bloc, não os Form das abas). personType 'N'
  /// não exige documento (Fase 3, decisão 4).
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
          length: 6,
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
                  Tab(text: 'forms.customer.tab'.tr()),
                  Tab(text: 'forms.customer.tax.tab'.tr()),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    EntityMainTab(
                      value: draft,
                      onChanged: (fiscal) =>
                          onDraftChanged(draft.mergeFiscal(fiscal)),
                      // Prefill by-document só na CRIAÇÃO (Fase 3, dec. 3/9/10)
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
                    CustomerTab(
                      value: draft,
                      onChanged: onDraftChanged,
                      salesmanLookup: salesmanLookup,
                      carrierLookup: carrierLookup,
                    ),
                    // Rodada 4: aba Tributação edita a fatia `tax` do draft
                    // (o form SEMPRE envia — toJson usa default se null)
                    CustomerTaxTab(
                      value: draft.tax ?? const EntityTaxData(),
                      onChanged: (tax) =>
                          onDraftChanged(draft.copyWith(tax: tax)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
