import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

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
    // Pós-login: aplica idioma salvo (decisão 14) e tema da institution (decisões 16/27)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.bloc == null) {
        applyUserLocale(context, Modular.get<GetPreferencesUsecase>());
        Modular.get<ThemeCubit>().load();
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
  Widget build(BuildContext context) => Responsive(
        mobile: ContentHomeMobile(bloc: bloc),
        desktop: ContentHomeDesktop(bloc: bloc),
      );
}
