import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../interface_routes.dart';
import '../bloc/menu_bloc.dart';

/// Shell mobile: módulos/interfaces em Drawer expansível; frame no corpo.
class ContentHomeMobile extends StatelessWidget {
  const ContentHomeMobile({required this.bloc, super.key});

  final MenuBloc bloc;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MenuBloc, MenuState>(
      bloc: bloc,
      // Erro na carga dos menus = dialog via PONTE (Framework de Mensagens,
      // R1/R7 — técnico ganha código de suporte); o corpo mantém a mensagem
      // como pano de fundo neutro.
      listener: (context, state) {
        if (state is MenuError) showFailureFeedback(context, state.failure);
      },
      builder: (context, state) {
        if (state is MenuLoading || state is MenuInitial) {
          return const SetesScaffold(body: SetesCircularProgressIndicator());
        }
        if (state is MenuError) {
          return SetesScaffold(
              body: Center(child: SetesText(state.message.tr())));
        }
        final loaded = state as MenuLoaded;

        return SetesScaffold(
          appBarTitle: 'app.title'.tr(),
          // Logo da institution (o leading fica com o hambúrguer do Drawer)
          // + idioma (decisões 13/14) + tema (decisões 16/27)
          appBarActions: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: InstitutionLogo(height: 32),
            ),
            const UserBadge(),
            const LanguageSelector(),
            SetesIconButton(
              icon: Icons.palette_outlined,
              tooltip: 'theme.title'.tr(),
              onPressed: () => Modular.to.pushNamed('/home/theme'),
            ),
          ],
          drawer: Drawer(
            child: ListView(
              children: [
                for (var i = 0; i < loaded.modules.length; i++)
                  ExpansionTile(
                    title: SetesText(loaded.modules[i].id != null
                        ? loaded.modules[i].description
                        : trCatalog(loaded.modules[i].description,
                            loaded.modules[i].description, prefix: 'menu.groups')),
                    leading: const Icon(Icons.apps_outlined),
                    children: [
                      for (final item in loaded.modules[i].interfaces)
                        SetesListTile(
                          title: SetesText(trCatalog(item.i18nKey, item.description,
                              prefix: 'menu.interfaces')),
                          onTap: () {
                            bloc.add(MenuInterfaceSelected(interfaceItem: item));
                            Navigator.of(context).pop();
                            navigateToInterface(item);
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
          // Conteúdo: módulo da interface ativa (1 interface = 1 módulo/rota)
          body: const RouterOutlet(),
        );
      },
    );
  }
}
