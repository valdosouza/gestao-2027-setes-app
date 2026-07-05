import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../bloc/menu_bloc.dart';
import 'interface_frame.dart';

/// Shell mobile: módulos/interfaces em Drawer expansível; frame no corpo.
class ContentHomeMobile extends StatelessWidget {
  const ContentHomeMobile({required this.bloc, super.key});

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
          drawer: Drawer(
            child: ListView(
              children: [
                for (var i = 0; i < loaded.modules.length; i++)
                  ExpansionTile(
                    title: SetesText(loaded.modules[i].description),
                    leading: const Icon(Icons.apps_outlined),
                    children: [
                      for (final item in loaded.modules[i].interfaces)
                        SetesListTile(
                          title: SetesText(item.description),
                          onTap: () {
                            bloc.add(MenuInterfaceSelected(interfaceItem: item));
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
              ],
            ),
          ),
          body: InterfaceFrame(interfaceItem: loaded.selectedInterface),
        );
      },
    );
  }
}
