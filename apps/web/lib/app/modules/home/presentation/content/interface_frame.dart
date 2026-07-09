import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Frame que renderiza a tela apontada pelo menu (layout do prompt).
/// Fase seguinte: mapear tb_interface.button_action → widget do cadastro
/// via fábrica RegisterSearchPage/RegisterFormPage (decisão 20).
class InterfaceFrame extends StatelessWidget {
  const InterfaceFrame({required this.interfaceItem, super.key});

  final MenuInterface? interfaceItem;

  @override
  Widget build(BuildContext context) {
    if (interfaceItem == null) {
      return Center(child: SetesText('home.welcome'.tr()));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetesText.title(trCatalog(interfaceItem!.i18nKey, interfaceItem!.description,
              prefix: 'menu.interfaces')),
          const SizedBox(height: 8),
          // Botões da UI respeitam os privilégios (decisão 21); rótulos traduzidos (decisão 26)
          Wrap(
            spacing: 8,
            children: [
              for (final privilege in interfaceItem!.privileges)
                Chip(label: SetesText(trCatalog(privilege, privilege, prefix: 'menu.privileges'))),
            ],
          ),
          const SizedBox(height: 24),
          SetesText('buttonAction: ${interfaceItem!.buttonAction ?? '-'}'),
        ],
      ),
    );
  }
}
