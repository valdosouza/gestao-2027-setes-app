import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  void Function()? _removeExpiredListener;

  @override
  void initState() {
    super.initState();
    // D-F138 (F2b, Valdo 2026-10-13): 401 numa requisição que levou o token
    // da sessão — em QUALQUER API do produto (setes-api, nfse-api) — = a
    // sessão morreu. UMA reação para o app inteiro: limpa a sessão salva,
    // volta o tema ao padrão e vai ao login (antes, cada tela mostrava um
    // diálogo "token inválido" e o usuário ficava preso nela). O "Manter
    // conectado" é preferência do usuário — a expiração não a revoga.
    _removeExpiredListener =
        Modular.get<ProductToken>().addExpiredListener(_onSessionExpired);
  }

  Future<void> _onSessionExpired() async {
    await Modular.get<LocalPrefs>().setSessionToken(null);
    Modular.get<ThemeCubit>().reset();
    Modular.to.navigate('/login');
  }

  @override
  void dispose() {
    _removeExpiredListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Modular.setInitialRoute('/login');

    // Tema dinâmico (decisões 16 e 27): padrão Setes antes do login;
    // após o login o ThemeCubit carrega as cores da institution e o
    // MaterialApp inteiro re-renderiza — nenhuma tela define cor.
    return BlocBuilder<ThemeCubit, SetesThemeState>(
      bloc: Modular.get<ThemeCubit>(),
      builder: (context, themeState) => MaterialApp.router(
        title: 'Setes ERP',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: themeState.themeData,
        routeInformationParser: Modular.routeInformationParser,
        routerDelegate: Modular.routerDelegate,
      ),
    );
  }
}
