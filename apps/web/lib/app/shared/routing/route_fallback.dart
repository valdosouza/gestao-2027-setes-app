import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// Rota de ESCAPE do app (`WildcardRoute`): endereço que nenhuma rota resolve (URL digitada, favorito antigo, link de outro
/// ambiente). Sem ela o `selectRoute` do flutter_modular lança o `RouteNotFound` e a TELA FICA EM BRANCO — achado do passeio
/// logado de 2026-10-14 (traduzido com source maps; o "não reproduzido" de 2026-10-13 era o mesmo defeito).
///
/// Leva a [to] (por padrão `/home/`: logado entra na casa; sem sessão a guarda de `/home` manda ao login) no primeiro quadro, com
/// um indicador de carga no lugar — nunca texto: o endereço digitado não é eco na tela.
class RouteFallback extends StatefulWidget {
  const RouteFallback({super.key, this.to = '/home/'});

  final String to;

  @override
  State<RouteFallback> createState() => _RouteFallbackState();
}

class _RouteFallbackState extends State<RouteFallback> {
  @override
  void initState() {
    super.initState();
    // navegar durante o build do roteador é recusado: depois do 1º quadro
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Modular.to.navigate(widget.to);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
