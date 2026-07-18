import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// Registro central i18nKey → rota do módulo da interface
/// (ARQUITETURA_MODULOS.md: 1 interface = 1 módulo, montado como
/// ModuleRoute filho do Home e renderizado no RouterOutlet).
///
/// Ao criar um módulo novo: adicionar a entrada aqui E a ModuleRoute
/// correspondente no HomeModule.
const Map<String, String> interfaceRoutes = {
  'countries':  '/home/countries/',
  'states':     '/home/states/',
  'cities':     '/home/cities/',
  'interfaces': '/home/interfaces/',
  'privileges': '/home/privileges/',
  'cfop':       '/home/cfop/',
  'institutions': '/home/institutions/',
  // Primeiro papel da Fase 3 Entidade Única (cadastro do CLIENTE)
  'customers':  '/home/customers/',
  // Onda 2 — papel Colaborador (hierarquia de papéis, decisão 16)
  'collaborators': '/home/collaborators/',
  // Categorias de produtos e serviços (cadastro do cliente)
  'categories': '/home/categories/',
  // Formas de pagamento (grupo Financeiro)
  'payment-types': '/home/payment-types/',
  // Plano de Contas (2o cadastro em arvore)
  'financial-plans': '/home/financial-plans/',
  // Painel Sistema/Admin de campos configuráveis (Fase 2, decisão 6)
  'interface-fields': '/home/interface-fields/',
  // Painel de configurações do sistema (Framework de Configurações, dec. 9)
  'interface-configs': '/home/interface-configs/',
  'users':      '/home/users/',
};

/// Navega para o módulo da interface clicada no menu, levando o NOME DA
/// INTERFACE como argumento (título das telas — decisão do Valdo 2026-07-11).
/// Interface sem módulo ainda → placeholder '/home/pending/'.
void navigateToInterface(MenuInterface item) {
  final title =
      trCatalog(item.i18nKey, item.description, prefix: 'menu.interfaces');

  // "Configurações Gerais" (decisão 3 do Framework de Configurações) é a
  // interface DONA das configs sem tela própria — não tem módulo: o clique
  // abre o painel de configurações já filtrado nela (mesmo caminho da
  // engrenagem das listas).
  if (item.i18nKey == 'general-configs') {
    Modular.to.navigate('/home/interface-configs/', arguments: {
      'title': title,
      'moduleKey': 'general-configs',
    });
    return;
  }

  final route = interfaceRoutes[item.i18nKey];
  if (route != null) {
    Modular.to.navigate(route, arguments: title);
  } else {
    Modular.to.navigate('/home/pending/',
        arguments: item.i18nKey ?? item.description);
  }
}
