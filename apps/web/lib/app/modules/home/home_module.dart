import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../bank_accounts/bank_accounts_module.dart';
import '../banks/banks_module.dart';
import '../carriers/carriers_module.dart';
import '../cashier/cashier_module.dart';
import '../categories/categories_module.dart';
import '../cfop/cfop_module.dart';
import '../cities/cities_module.dart';
import '../collaborators/collaborators_module.dart';
import '../contracts/contracts_module.dart';
import '../countries/countries_module.dart';
import '../customers/customers_module.dart';
import '../establishment/establishment_module.dart';
import '../financial_plans/financial_plans_module.dart';
import '../institutions/institutions_module.dart';
import '../interface_configs/interface_configs_module.dart';
import '../payment_types/payment_types_module.dart';
import '../price_lists/price_lists_module.dart';
import '../service_list/service_list_module.dart';
import '../interface_fields/interface_fields_module.dart';
import '../interfaces/interfaces_module.dart';
import '../modules/modules_module.dart';
import '../order_returns/order_returns_module.dart';
import '../orders/orders_module.dart';
import '../privileges/privileges_module.dart';
import '../providers/providers_module.dart';
import '../salesmen/salesmen_module.dart';
import '../service_orders/service_orders_module.dart';
import '../service_tax_rules/service_tax_rules_module.dart';
import '../services/services_module.dart';
import '../settlements/settlements_module.dart';
import '../states/states_module.dart';
import '../tax_rules/tax_rules_module.dart';
import '../users/users_module.dart';
import 'presentation/bloc/menu_bloc.dart';
import 'presentation/content/home_frames.dart';
import 'presentation/page/home_page.dart';

/// Shell pós-login. Cada interface do menu é um módulo independente
/// (ARQUITETURA_MODULOS.md, padrão weberpsetes): ModuleRoute filha da rota
/// '/', renderizada no RouterOutlet do conteúdo central. O clique no menu
/// faz Modular.to.navigate (interface_routes.dart) — binds de cada módulo
/// só vivem enquanto sua rota está ativa.
class HomeModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<MenuRemoteDatasource>(
            (i) => MenuRemoteDatasource(client: i.get<ApiClient>())),
        Bind.lazySingleton<MenuRepository>(
            (i) => MenuRepositoryImpl(datasource: i.get<MenuRemoteDatasource>())),
        Bind.factory<GetMenusUsecase>(
            (i) => GetMenusUsecase(repository: i.get<MenuRepository>())),
        Bind.singleton<MenuBloc>((i) => MenuBloc(usecase: i.get<GetMenusUsecase>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => const HomePage(),
          children: [
            // Conteúdo do RouterOutlet: 1 interface = 1 módulo
            ChildRoute('/welcome', child: (_, __) => const WelcomeFrame()),
            ChildRoute('/pending', child: (_, __) => const PendingInterfaceFrame()),
            ModuleRoute('/countries',  module: CountriesModule()),
            ModuleRoute('/states',     module: StatesModule()),
            ModuleRoute('/cities',     module: CitiesModule()),
            ModuleRoute('/interfaces', module: InterfacesModule()),
            ModuleRoute('/privileges', module: PrivilegesModule()),
            // Referencia fiscal do catalogo central (modulo Super)
            ModuleRoute('/cfop', module: CfopModule()),
            // Lista de Serviços da LC 116 (catálogo central, módulo Super)
            ModuleRoute('/service-list', module: ServiceListModule()),
            // Catálogo FEBRABAN central (módulo Super — decisão 2026-08-04,
            // fecho da decisão 8 da Fase 3; sem cadeia fiscal)
            ModuleRoute('/banks', module: BanksModule()),
            ModuleRoute('/institutions', module: InstitutionsModule()),
            // Meu Estabelecimento (menu Sistema) — CRUD sem lista
            ModuleRoute('/establishment', module: EstablishmentModule()),
            // Fase 3 Entidade Única — primeiro papel novo (Customer)
            ModuleRoute('/customers', module: CustomersModule()),
            // Onda 2 — papel Colaborador (hierarquia de papéis, decisão 16)
            ModuleRoute('/collaborators', module: CollaboratorsModule()),
            // Onda 2 — Vendedor (promoção de colaborador, D1) e
            // Transportadora (cadeia fiscal + Tributação, D2)
            ModuleRoute('/salesmen', module: SalesmenModule()),
            ModuleRoute('/carriers', module: CarriersModule()),
            // Onda 3 — Fornecedor (espelho do carrier: cadeia fiscal +
            // Tributação, D1 da Onda 3)
            ModuleRoute('/providers', module: ProvidersModule()),
            // Categorias de produtos e serviços (cadastro do cliente)
            ModuleRoute('/categories', module: CategoriesModule()),
            // Formas de pagamento (grupo Financeiro)
            ModuleRoute('/payment-types', module: PaymentTypesModule()),
            // Plano de Contas (2o cadastro em arvore)
            ModuleRoute('/financial-plans', module: FinancialPlansModule()),
            // Regras de Tributação (fase Faturamento Fiscal e Financeiro —
            // seletor + peças por tributo, presença = incidência)
            ModuleRoute('/tax-rules', module: TaxRulesModule()),
            // Contratos de serviço (Módulo Software House)
            ModuleRoute('/contracts', module: ContractsModule()),
            // Contas Bancárias (Módulo Software House, grupo Financeiro)
            ModuleRoute('/bank-accounts', module: BankAccountsModule()),
            // Ordens de Serviço (Módulo Software House, grupo Serviços —
            // 1ª tela de processo: ciclo mensal + Gerar Faturamento)
            ModuleRoute('/service-orders', module: ServiceOrdersModule()),
            // Baixa de Títulos (Módulo Software House, grupo Financeiro —
            // 2ª tela de processo: carteira, baixa em lote, estorno, extrato)
            ModuleRoute('/settlements', module: SettlementsModule()),
            // Abertura/Fechamento de Caixa (grupo Financeiro — 3º TIPO de
            // tela: sessão/status, não lista+form nem árvore, W3.2)
            ModuleRoute('/cashier', module: CashierModule()),
            // Tabelas de Preço e Serviços (prompt_modulo_services.md,
            // D1–D7: serviço = tb_product kind='S' + grade de preços por
            // tabela; telas irmãs do futuro cadastro de produtos — D6)
            ModuleRoute('/price-lists', module: PriceListsModule()),
            ModuleRoute('/services', module: ServicesModule()),
            // Regras de Tributação de Serviço (ISS — D1–D14: cidade de
            // incidência × item LC 116 → alíquota + código municipal)
            ModuleRoute('/service-tax-rules', module: ServiceTaxRulesModule()),
            // Módulos de Menu do cliente (camada 2 do menu — D1–D4)
            ModuleRoute('/modules', module: ModulesModule()),
            // Pedido de Venda / Conjugado (grupo Vendas — 3ª tela de
            // processo: itens mercadoria/serviço + Validar e Faturar)
            ModuleRoute('/orders', module: OrdersModule()),
            // Devolução de Mercadoria (grupo Vendas — ajuste de Entrada
            // ancorado no pedido de venda faturado, molde orders)
            ModuleRoute('/order-returns', module: OrderReturnsModule()),
            // Painel Sistema/Admin de campos configuráveis (Fase 2, decisão 6)
            ModuleRoute('/interface-fields', module: InterfaceFieldsModule()),
            // Painel de configurações do sistema (Framework de Configurações)
            ModuleRoute('/interface-configs', module: InterfaceConfigsModule()),
            ModuleRoute('/users', module: UsersModule()),
          ],
        ),
        // Personalização da identidade visual pelo cliente (decisões 16/27)
        ChildRoute('/theme', child: (_, __) => const ThemeSettingsPage()),
      ];
}
