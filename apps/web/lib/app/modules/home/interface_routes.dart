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
};

/// Navega para o módulo da interface clicada no menu, levando o NOME DA
/// INTERFACE como argumento (título das telas — decisão do Valdo 2026-07-11).
/// Interface sem módulo ainda → placeholder '/home/pending/'.
void navigateToInterface(MenuInterface item) {
  final title =
      trCatalog(item.i18nKey, item.description, prefix: 'menu.interfaces');
  final route = interfaceRoutes[item.i18nKey];
  if (route != null) {
    Modular.to.navigate(route, arguments: title);
  } else {
    Modular.to.navigate('/home/pending/',
        arguments: item.i18nKey ?? item.description);
  }
}
