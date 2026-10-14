// Rota de escape × o shell da casa. Achado do navegador (2026-10-14): o `WildcardRoute` no nível do HomeModule fazia a Home entrar em
// LAÇO (a `HomePage` navega de `/home/` para `/home/welcome/`; o escape capturava o endereço e voltava a `/home/`). Este teste
// reproduz a forma real: shell com `RouterOutlet` e o redirecionamento ao welcome no 1º quadro, e mede quantas vezes a casa é criada.
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/routing/route_fallback.dart';

int homeBuilds = 0;

class _HomeShell extends StatefulWidget {
  const _HomeShell();
  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  @override
  void initState() {
    super.initState();
    homeBuilds++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final path = Modular.to.path;
      if (mounted && (path == '/home' || path == '/home/')) Modular.to.navigate('/home/welcome/');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Column(children: [Text('SHELL'), Expanded(child: RouterOutlet())]));
}

enum _Variant { wildcardInModule, wildcardInChildren, appLevelOnly }

class _HomeLike extends Module {
  _HomeLike(this.variant);
  final _Variant variant;

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, __) => const _HomeShell(), children: [
          ChildRoute('/welcome', child: (_, __) => const Text('BEM-VINDO')),
          if (variant == _Variant.wildcardInChildren) WildcardRoute(child: (_, __) => const Text('BEM-VINDO')),
        ]),
        if (variant == _Variant.wildcardInModule) WildcardRoute(child: (_, __) => const RouteFallback()),
      ];
}

class _AuthLike extends Module {
  @override
  List<ModularRoute> get routes => [ChildRoute('/login', child: (_, __) => const Text('LOGIN'))];
}

class _Root extends Module {
  _Root(this.variant);
  final _Variant variant;
  @override
  List<ModularRoute> get routes => [
        ModuleRoute('/', module: _AuthLike()),
        ModuleRoute('/home', module: _HomeLike(variant)),
        WildcardRoute(child: (_, __) => const RouteFallback()),
      ];
}

/// Sobe o app no endereço [initial], deixa 3 s de relógio do teste rolarem e devolve o que ficou na tela e quantas vezes a casa nasceu.
Future<({String shown, int builds})> _run(WidgetTester tester, _Variant v, String initial) async {
  homeBuilds = 0;
  Modular.setInitialRoute(initial);
  await tester.pumpWidget(ModularApp(
    module: _Root(v),
    child: MaterialApp.router(routeInformationParser: Modular.routeInformationParser, routerDelegate: Modular.routerDelegate),
  ));
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final shown = ['SHELL', 'BEM-VINDO', 'LOGIN'].where((s) => find.text(s).evaluate().isNotEmpty).join(',');
  final builds = homeBuilds;
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
  return (shown: shown, builds: builds);
}

void main() {
  final variant = _Variant.values.firstWhere(
    (v) => v.name == const String.fromEnvironment('ROUTE_VARIANT', defaultValue: 'wildcardInChildren'),
  );

  testWidgets('abertura em /home/ (o redirecionamento ao welcome): a casa nasce UMA vez — variante ${variant.name}', (tester) async {
    final r = await _run(tester, variant, '/home/');
    // ignore: avoid_print
    print('LOOP ${variant.name} /home/ -> ${r.shown} · casa criada ${r.builds}x');
    expect(r.builds, 1);
    expect(r.shown, 'SHELL,BEM-VINDO');
  });
}
