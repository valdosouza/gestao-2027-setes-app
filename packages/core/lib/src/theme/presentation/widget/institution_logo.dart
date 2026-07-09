import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../cubit/theme_cubit.dart';

/// Logomarca da institution na HOME (decisão 16): usa a logo carregada pelo
/// cliente (tb_institution_theme.logo_path, servida como base64 pela API);
/// sem logo própria → fallback = ícone Setes.
///
/// Contrato com o app hospedeiro: declarar o asset [fallbackAssetPath].
/// No LOGIN a logo é SEMPRE a da Setes (asset direto, sem este widget).
class InstitutionLogo extends StatelessWidget {
  const InstitutionLogo({
    this.height = 32,
    this.fallbackAssetPath = 'assets/images/icone_setes.png',
    this.cubit,
    super.key,
  });

  final double height;
  final String fallbackAssetPath;

  /// Optional cubit for tests; when null, uses `Modular.get<ThemeCubit>()`.
  final ThemeCubit? cubit;

  @override
  Widget build(BuildContext context) => BlocBuilder<ThemeCubit, SetesThemeState>(
        bloc: cubit ?? Modular.get<ThemeCubit>(),
        builder: (context, state) {
          final logo = state.logoBase64;
          if (logo != null && logo.contains(',')) {
            try {
              return Image.memory(
                base64Decode(logo.split(',').last),
                height: height,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              );
            } catch (_) {/* base64 inválido → fallback */}
          }
          return Image.asset(fallbackAssetPath, height: height, fit: BoxFit.contain);
        },
      );
}
