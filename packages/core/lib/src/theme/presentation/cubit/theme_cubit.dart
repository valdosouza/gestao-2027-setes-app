import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/usecase/get_theme_usecase.dart';
import '../../domain/usecase/save_theme_usecase.dart';
import '../../setes_theme.dart';

/// Estado do tema aplicado (decisão 27). themeData fica fora do props —
/// a igualdade é decidida pelas cores/logo persistidas.
class SetesThemeState extends Equatable {
  SetesThemeState({
    required this.themeData,
    this.primaryHex,
    this.secondaryHex,
    this.logoBase64,
  });

  final ThemeData themeData;
  final String? primaryHex;
  final String? secondaryHex;
  final String? logoBase64;

  factory SetesThemeState.initial() => SetesThemeState(themeData: SetesTheme.build());

  @override
  List<Object?> get props => [primaryHex, secondaryHex, logoBase64];
}

/// Carrega o tema da institution após o login e aplica na hora as
/// alterações do cliente (tela de personalização) — decisões 16 e 27.
class ThemeCubit extends Cubit<SetesThemeState> {
  ThemeCubit({required this.getUsecase, required this.saveUsecase})
      : super(SetesThemeState.initial());

  final GetThemeUsecase getUsecase;
  final SaveThemeUsecase saveUsecase;

  Future<void> load() async {
    final result = await getUsecase();
    result.fold(
      (_) {}, // sem tema: mantém o padrão Setes
      (theme) => emit(SetesThemeState(
        themeData: SetesTheme.build(
          primary: SetesTheme.colorFromHex(theme.primaryColor),
          secondary: SetesTheme.colorFromHex(theme.secondaryColor),
        ),
        primaryHex: theme.primaryColor,
        secondaryHex: theme.secondaryColor,
        logoBase64: theme.logoBase64,
      )),
    );
  }

  /// Aplica imediatamente e persiste na API (PUT /api/core/theme).
  Future<void> save({String? primaryHex, String? secondaryHex}) async {
    final newPrimary = primaryHex ?? state.primaryHex;
    final newSecondary = secondaryHex ?? state.secondaryHex;
    emit(SetesThemeState(
      themeData: SetesTheme.build(
        primary: SetesTheme.colorFromHex(newPrimary),
        secondary: SetesTheme.colorFromHex(newSecondary),
      ),
      primaryHex: newPrimary,
      secondaryHex: newSecondary,
      logoBase64: state.logoBase64,
    ));
    await saveUsecase(primaryColor: newPrimary, secondaryColor: newSecondary);
  }

  /// Logo da institution carregada pelo cliente (decisão 16) — aparece
  /// só na HOME (no login a logo é sempre da Setes).
  Future<void> saveLogo(String logoBase64DataUri) async {
    emit(SetesThemeState(
      themeData: state.themeData,
      primaryHex: state.primaryHex,
      secondaryHex: state.secondaryHex,
      logoBase64: logoBase64DataUri,
    ));
    await saveUsecase(logoBase64: logoBase64DataUri);
  }

  /// Volta ao padrão Setes (logout / antes do login).
  void reset() => emit(SetesThemeState.initial());
}
