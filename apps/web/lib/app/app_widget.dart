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
    final session = Modular.get<ProductToken>();
    _removeExpiredListener = session.addExpiredListener(_onSessionExpired);
    // D-F148 (= Q-F160 (a)): o 401 de uma API que NÃO emitiu o token (a
    // nfse-api) só derruba a sessão se o EMISSOR (o setes-api) confirmar —
    // chave de assinatura nova que a nfse-api ainda não conhece não desloga o
    // usuário em laço a cada OS faturada aberta.
    session.confirmer = Modular.get<ApiClient>().sessionAlive;
  }

  Future<void> _onSessionExpired() async {
    try {
      // várias abas dividem a sessão SALVA: só limpa se for a que expirou (a
      // aba velha não apaga o login novo da outra — F2B-ADV-11)
      final prefs = Modular.get<LocalPrefs>();
      final stored = await prefs.getSessionToken();
      final expired = Modular.get<ProductToken>().lastExpired;
      if (stored == null || stored == expired) await prefs.setSessionToken(null);
      Modular.get<ThemeCubit>().reset();
    } catch (_) {
      // a ida ao login abaixo não depende da limpeza
    }
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
