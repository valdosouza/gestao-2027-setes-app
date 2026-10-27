import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../../shared/session/current_interface.dart';
import '../../../../shared/session/session_context.dart';
import '../bloc/menu_bloc.dart';
import '../content/content_home_desktop.dart';
import '../content/content_home_mobile.dart';

/// Shell da home (decisão 5: page + contents por breakpoint).
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.bloc});

  /// Optional bloc for tests; when null, uses `Modular.get<MenuBloc>()`.
  final MenuBloc? bloc;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MenuBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc ?? Modular.get<MenuBloc>();
    bloc.add(const MenuLoadRequested());
    // D-PV17: a cada navegação a tela aberta liga ao item do menu do SEU módulo (o "Devolver" do pedido, a engrenagem,
    // a aba hospedada trocam a interface dos botões); sem o item no menu, `can` = falso
    Modular.to.addListener(_onRouteChanged);
    _onRouteChanged();
    // Pós-login: aplica idioma salvo (decisão 14) e tema da institution (decisões 16/27)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.bloc == null) {
        applyUserLocale(context, Modular.get<GetPreferencesUsecase>());
        Modular.get<ThemeCubit>().load();
        _hydrateSessionContext();
        // RouterOutlet precisa de uma rota filha ativa: sem interface na URL
        // (login normal), abre o welcome. Refresh em /home/<interface>/ mantém.
        final path = Modular.to.path;
        if (path == '/home' || path == '/home/') {
          Modular.to.navigate('/home/welcome/');
        }
      }
    });
  }

  @override
  void dispose() {
    Modular.to.removeListener(_onRouteChanged);
    super.dispose();
  }

  /// D-PV17: liga a tela aberta ao item do menu do módulo da rota. A "Configurações Gerais" não tem módulo — abre o painel de
  /// configurações filtrado nela (`moduleKey: 'general-configs'` nos arguments) e a interface dos botões é a DELA.
  void _onRouteChanged() {
    final args = Modular.args.data;
    final general = args is Map && args['moduleKey'] == 'general-configs' ? 'general-configs' : null;
    CurrentInterface.bindRoute(Modular.to.path, interfaceKey: general);
  }

  /// SessionContext (decisão 17): re-hidrata os fatos derivados de sessão
  /// via /api/core/me a CADA entrada na Home — cobre login, refresh (o
  /// bloco `context` do login não sobrevive ao F5) e troca de institution.
  /// Falha silenciosa: o contexto zerado só degrada UX (enforcement na API).
  Future<void> _hydrateSessionContext() async {
    final result = await Modular.get<GetMeUsecase>()();
    result.fold(
      (_) {},
      (me) => Modular.get<SessionContext>().applyJson(me.context),
    );
  }

  @override
  Widget build(BuildContext context) => Responsive(
        mobile: ContentHomeMobile(bloc: bloc),
        desktop: ContentHomeDesktop(bloc: bloc),
      );
}
