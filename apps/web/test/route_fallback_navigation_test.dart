// Rota de escape (WildcardRoute) — NAVEGAÇÃO (o Modular é singleton: a abertura a frio vive em route_fallback_test.dart)
// Rota de escape (WildcardRoute) — achado E1 do passeio logado de 2026-10-14: endereço desconhecido deixava a tela EM BRANCO
// (RouteNotFound do flutter_modular, sem rota coringa). Módulos leves com a MESMA forma do app: `ModuleRoute('/')` do login,
// `ModuleRoute('/home')` com a rota de escape em cada nível. O Modular é um singleton global: cada teste desmonta o app no fim.
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/routing/route_fallback.dart';

class _AuthLike extends Module {
  @override
  List<ModularRoute> get routes => [
        ChildRoute('/login', child: (_, __) => const Scaffold(body: Text('TELA-LOGIN'))),
      ];
}

class _HomeLike extends Module {
  _HomeLike({required this.withWildcard});
  final bool withWildcard;

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, __) => const Scaffold(body: Text('TELA-HOME')), children: [
          ChildRoute('/welcome', child: (_, __) => const Text('BEM-VINDO')),
          // o escape da casa vive NOS FILHOS (no nivel do modulo ele captura /home/welcome/ e a casa entra em laco — route_fallback_loop_test)
          if (withWildcard) WildcardRoute(child: (_, __) => const Text('BEM-VINDO')),
        ]),
      ];
}

class _RootModule extends Module {
  _RootModule({required this.withWildcard});
  final bool withWildcard;

  @override
  List<ModularRoute> get routes => [
        ModuleRoute('/', module: _AuthLike()),
        ModuleRoute('/home', module: _HomeLike(withWildcard: withWildcard)),
        if (withWildcard) WildcardRoute(child: (_, __) => const RouteFallback()),
      ];
}

Future<void> _boot(WidgetTester tester, {required bool withWildcard, String initial = '/login'}) async {
  Modular.setInitialRoute(initial);
  await tester.pumpWidget(ModularApp(
    module: _RootModule(withWildcard: withWildcard),
    child: MaterialApp.router(
      routeInformationParser: Modular.routeInformationParser,
      routerDelegate: Modular.routerDelegate,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Qual das duas telas está de pé ('' = tela em branco).
String _shown() => ['TELA-LOGIN', 'TELA-HOME'].where((s) => find.text(s).evaluate().isNotEmpty).join(',');

Future<void> _teardown(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('navegação para um endereço desconhecido, do login, com a rota de escape: cai na casa', (tester) async {
    await _boot(tester, withWildcard: true);
    expect(_shown(), 'TELA-LOGIN');
    Modular.to.navigate('/nada-aqui/');
    await tester.pumpAndSettle();
    expect(_shown(), 'TELA-HOME');
    await _teardown(tester);
  });
}
