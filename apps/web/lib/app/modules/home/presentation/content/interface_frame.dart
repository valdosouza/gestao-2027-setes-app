import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../super/presentation/cities/city_page.dart';
import '../../../super/presentation/countries/country_page.dart';
import '../../../super/presentation/states/state_page.dart';

/// Frame que renderiza a tela apontada pelo menu.
/// Roteamento via i18nKey (decisão 20): cada chave mapeia para um widget
/// de cadastro. Telas não mapeadas mostram placeholder.
///
/// O título das telas é o NOME DA INTERFACE do menu (trCatalog, mesmo texto
/// que o usuário clicou) — decisão do Valdo 2026-07-11.
class InterfaceFrame extends StatelessWidget {
  const InterfaceFrame({required this.interfaceItem, super.key});

  final MenuInterface? interfaceItem;

  Widget _resolveContent(String i18nKey, String title) {
    switch (i18nKey) {
      case 'countries':
        return CountryPage(title: title);
      case 'states':
        return StatePage(title: title);
      case 'cities':
        return CityPage(title: title);
      default:
        return Center(
          child: SetesText('home.not_implemented'.tr(args: [i18nKey])),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (interfaceItem == null) {
      return Center(child: SetesText('home.welcome'.tr()));
    }
    final item = interfaceItem!;
    final title = trCatalog(item.i18nKey, item.description, prefix: 'menu.interfaces');
    return _resolveContent(item.i18nKey ?? '', title);
  }
}
