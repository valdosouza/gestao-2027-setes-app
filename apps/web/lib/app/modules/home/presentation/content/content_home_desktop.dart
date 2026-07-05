import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../bloc/menu_bloc.dart';
import 'interface_frame.dart';

/// Shell desktop (layout do prompt): menu vertical de módulos → menu de
/// interfaces → frame. Acionamento por CLIQUE, nunca mouse-over (decisão 22).
class ContentHomeDesktop extends StatelessWidget {
  const ContentHomeDesktop({required this.bloc, super.key});

  final MenuBloc bloc;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuBloc, MenuState>(
      bloc: bloc,
      builder: (context, state) {
        if (state is MenuLoading || state is MenuInitial) {
          return const SetesScaffold(body: SetesCircularProgressIndicator());
        }
        if (state is MenuError) {
          return SetesScaffold(body: Center(child: SetesText(state.message)));
        }
        final loaded = state as MenuLoaded;

        return SetesScaffold(
          appBarTitle: 'app.title'.tr(),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coluna 1 — módulos (Super, Sistema, ...)
              SizedBox(
                width: 200,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListView.builder(
                    itemCount: loaded.modules.length,
                    itemBuilder: (context, index) {
                      final module = loaded.modules[index];
                      return SetesListTile(
                        title: SetesText(module.description),
                        leading: const Icon(Icons.apps_outlined),
                        selected: loaded.selectedModuleIndex == index,
                        onTap: () => bloc.add(MenuModuleSelected(index: index)),
                      );
                    },
                  ),
                ),
              ),
              // Coluna 2 — interfaces do módulo clicado
              if (loaded.selectedModule != null)
                SizedBox(
                  width: 240,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: ListView.builder(
                      itemCount: loaded.selectedModule!.interfaces.length,
                      itemBuilder: (context, index) {
                        final item = loaded.selectedModule!.interfaces[index];
                        return SetesListTile(
                          title: SetesText(item.description),
                          selected: loaded.selectedInterface?.id == item.id,
                          onTap: () => bloc.add(MenuInterfaceSelected(interfaceItem: item)),
                        );
                      },
                    ),
                  ),
                ),
              // Frame que renderiza a tela apontada pelo menu
              Expanded(child: InterfaceFrame(interfaceItem: loaded.selectedInterface)),
            ],
          ),
        );
      },
    );
  }
}
