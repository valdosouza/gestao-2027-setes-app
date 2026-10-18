import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/icons/material_icon_names.dart';
import '../../interface_routes.dart';
import '../bloc/menu_bloc.dart';

/// Medidas do shell da casa (onda D da densidade — `Infra-IA/prompts/prompt_densidade_layout_web.md` §5).
abstract final class HomeLayout {
  /// D-DL7 (Valdo): largura da ÁREA ÚTIL do shell (medida pelo `LayoutBuilder`, nunca pela janela) a partir da qual o menu fica
  /// ao lado do conteúdo — a faixa "expandida" do Material 3, a mesma da grade dos formulários (`SetesFormGrid`). Abaixo dela o menu
  /// vira gaveta (☰). O notebook de 1366 px com o Windows em 125 % chega com 1093 px e fica com o menu ao lado.
  static const double sideMenuMinWidth = 840;

  /// Coluna 1 (módulos) e coluna 2 (interfaces do módulo — recolhível, D-DL7).
  static const double modulesWidth = 200;
  static const double interfacesWidth = 240;
}

/// Shell adaptativo ÚNICO da casa: UMA árvore para todas as larguras; só o MENU muda — colunas ao lado do conteúdo (área larga) ×
/// gaveta aberta pelo ☰ (área estreita). Acionamento por CLIQUE, nunca mouse-over (decisão 22).
///
/// D-DL6 (Valdo) — barra: com o menu ao lado NÃO existe barra do shell; a logomarca fica no topo da coluna de módulos e o usuário,
/// o idioma e o tema no pé dela — a única barra é a da tela aberta. Na gaveta, a barra do shell é enxuta: ☰ + logomarca + o botão
/// do usuário SÓ com o ícone (nome, idioma, tema e Sair dentro do menu dele). Antes, logo + nome + idioma + tema somavam ~360 px:
/// a 375 px a barra os alinhava à direita POR CIMA do ☰ e o menu ficava sem acesso.
///
/// ⚠️ CONHECIMENTO NEGATIVO (bug do passeio de 2026-10-17): o shell NUNCA escolhe entre duas árvores pela largura. O antigo
/// `Responsive(mobile: ContentHomeMobile, desktop: ContentHomeDesktop)` recriava o `RouterOutlet` ao cruzar o breakpoint
/// (maximizar ou restaurar a janela): a tela aberta nascia de novo e o formulário em edição voltava para a lista, perdendo o que
/// tinha sido digitado. Aqui o `RouterOutlet` fica SEMPRE na mesma posição da árvore (`_outletSlot`) e o que muda de uma largura
/// para a outra é só o CONTEÚDO dos outros espaços. Provas: `test/home_shell_resize_test.dart` e `test/home_shell_drawer_test.dart`.
class ContentHome extends StatelessWidget {
  const ContentHome({
    required this.bloc,
    this.logo,
    this.barAccount,
    this.menuFooter,
    super.key,
  });

  final MenuBloc bloc;

  /// Logomarca da institution (decisão 16). Optional for tests; when null, uses [InstitutionLogo].
  final Widget? logo;

  /// Botão do usuário na barra da gaveta. Optional for tests; when null, the compact [UserBadge] with language and theme.
  final Widget? barAccount;

  /// Pé da coluna de módulos (usuário + idioma + tema). Optional for tests; when null, the real widgets.
  final Widget? menuFooter;

  static const _outletSlot = ValueKey('home-shell-outlet');
  static const _menuSlot = ValueKey('home-shell-menu');

  Widget _logo(double height) => logo ?? InstitutionLogo(height: height);

  void _openTheme() => Modular.to.pushNamed('/home/theme');

  /// Idioma (decisões 13/14) e tema (16/27) dentro do menu do usuário — o contexto é o do badge, que segue montado.
  List<UserBadgeEntry> _preferenceEntries(BuildContext context) => [
        for (final locale in context.supportedLocales)
          UserBadgeEntry(
            label: LanguageSelector.labelOf(locale),
            checked: locale.languageCode == context.locale.languageCode,
            onSelected: () => LanguageSelector.change(context, locale),
          ),
        UserBadgeEntry(icon: Icons.palette_outlined, label: 'theme.title'.tr(), onSelected: _openTheme),
      ];

  Widget _barAccount() => barAccount ?? UserBadge(compact: true, entriesBuilder: _preferenceEntries);

  Widget _menuFooter() =>
      menuFooter ??
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usuário logado (nome com reticências na largura da coluna) + idioma + tema
          const UserBadge(),
          Row(children: [
            const LanguageSelector(),
            SetesIconButton(icon: Icons.palette_outlined, tooltip: 'theme.title'.tr(), onPressed: _openTheme),
          ]),
        ],
      );

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

        return LayoutBuilder(builder: (context, constraints) {
          final side = constraints.maxWidth >= HomeLayout.sideMenuMinWidth;
          return SetesScaffold(
            // Menu ao lado: sem barra do shell (D-DL6). Gaveta: ☰ (implícito) + logomarca + usuário.
            appBarTitleWidget: side ? null : _logo(32),
            appBarActions: side ? null : [_barAccount()],
            drawer: side ? null : Drawer(child: _DrawerMenu(bloc: bloc, loaded: loaded)),
            // Os DOIS espaços existem em toda largura, sempre na mesma ordem e com chave: o menu lateral só fica vazio na área
            // estreita — assim o `RouterOutlet` nunca muda de posição (ver o conhecimento negativo acima).
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: _menuSlot,
                  child: side
                      ? _SideMenu(bloc: bloc, loaded: loaded, logo: _logo, footer: _menuFooter())
                      : const SizedBox.shrink(),
                ),
                // Conteúdo central: módulo da interface ativa
                // (ARQUITETURA_MODULOS.md — 1 interface = 1 módulo/rota)
                const Expanded(key: _outletSlot, child: RouterOutlet()),
              ],
            ),
          );
        });
      },
    );
  }
}

String _moduleTitle(MenuModule module) =>
    // tb_module do cliente (id != null): texto como cadastrado.
    // Pseudo-módulo do catálogo (group_default): traduz (decisão 26).
    module.id != null
        ? module.description
        : trCatalog(module.description, module.description, prefix: 'menu.groups');

// Ícone por NOME Material do tb_module (D4); null/desconhecido = ícone padrão.
IconData _moduleIcon(MenuModule module) => materialIconByName(module.icon) ?? Icons.apps_outlined;

String _interfaceTitle(MenuInterface item) =>
    trCatalog(item.i18nKey, item.description, prefix: 'menu.interfaces');

/// Área larga: coluna de módulos (logomarca no topo, usuário/idioma/tema no pé) → coluna das interfaces do módulo clicado,
/// recolhível (D-DL7). Os cabeçalhos das duas colunas têm a altura e a cor da barra: com a barra da tela, formam UMA faixa.
class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.bloc, required this.loaded, required this.logo, required this.footer});

  final MenuBloc bloc;
  final MenuLoaded loaded;
  final Widget Function(double height) logo;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barHeight = theme.appBarTheme.toolbarHeight ?? kToolbarHeight;
    final barColor = theme.appBarTheme.backgroundColor ?? scheme.surface;
    final barText = theme.appBarTheme.foregroundColor ?? scheme.onSurface;
    final selected = loaded.selectedModule;
    final showInterfaces = selected != null && !loaded.interfacesCollapsed;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Coluna 1 — módulos (Super, Sistema, ...)
        SizedBox(
          width: HomeLayout.modulesWidth,
          child: Material(
            color: scheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logomarca da institution (decisão 16) no lugar da antiga barra do shell
                Container(
                  height: barHeight,
                  color: barColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: logo(barHeight - 16),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: loaded.modules.length,
                    itemBuilder: (context, index) {
                      final module = loaded.modules[index];
                      final isSelected = loaded.selectedModuleIndex == index;
                      return SetesListTile(
                        title: SetesText(_moduleTitle(module)),
                        leading: Icon(_moduleIcon(module)),
                        // Coluna das telas recolhida: o módulo aberto mostra que ela está ali (o clique a mostra de novo).
                        trailing: isSelected && loaded.interfacesCollapsed
                            ? Tooltip(
                                message: 'home.expandInterfaces'.tr(),
                                child: const Icon(Icons.chevron_right),
                              )
                            : null,
                        selected: isSelected,
                        onTap: () => bloc.add(MenuModuleSelected(index: index)),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: footer),
              ],
            ),
          ),
        ),
        // Coluna 2 — interfaces do módulo clicado
        if (showInterfaces)
          SizedBox(
            width: HomeLayout.interfacesWidth,
            child: Material(
              color: scheme.surfaceContainerHigh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: barHeight,
                    color: barColor,
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _moduleTitle(selected),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(color: barText),
                          ),
                        ),
                        SetesIconButton(
                          icon: Icons.chevron_left,
                          color: barText,
                          tooltip: 'home.collapseInterfaces'.tr(),
                          onPressed: () => bloc.add(const MenuInterfacesCollapseToggled()),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: selected.interfaces.length,
                      itemBuilder: (context, index) {
                        final item = selected.interfaces[index];
                        return SetesListTile(
                          title: SetesText(_interfaceTitle(item)),
                          selected: loaded.selectedInterface?.id == item.id,
                          onTap: () {
                            bloc.add(MenuInterfaceSelected(interfaceItem: item));
                            navigateToInterface(item);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Área estreita: módulos/interfaces na gaveta, em grupos expansíveis.
class _DrawerMenu extends StatelessWidget {
  const _DrawerMenu({required this.bloc, required this.loaded});

  final MenuBloc bloc;
  final MenuLoaded loaded;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          for (final module in loaded.modules)
            ExpansionTile(
              title: SetesText(_moduleTitle(module)),
              leading: Icon(_moduleIcon(module)),
              children: [
                for (final item in module.interfaces)
                  SetesListTile(
                    title: SetesText(_interfaceTitle(item)),
                    onTap: () {
                      bloc.add(MenuInterfaceSelected(interfaceItem: item));
                      Navigator.of(context).pop();
                      navigateToInterface(item);
                    },
                  ),
              ],
            ),
        ],
      );
}
