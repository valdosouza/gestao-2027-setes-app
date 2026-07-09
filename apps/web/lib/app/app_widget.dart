import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

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
