// Apoio dos testes do shell da casa (onda D da densidade): sobe o `ContentHome` REAL com o `RouterOutlet` de verdade (Modular) e um
// formulário com a forma do da fábrica dentro dele. O Modular é singleton: cada arquivo de teste sobe UM cenário.
// ⚠️ Com um campo focado o cursor pisca para sempre: `pumpAndSettle` nunca assenta (o teste trava) — depois do foco, só [settleShell].
// ⚠️ `bloc.close()` no relógio falso do testWidgets nunca completa: [tearDownShell] fecha no relógio real.
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show Either, Right;
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/home/presentation/bloc/menu_bloc.dart';
import 'package:setes_web/app/modules/home/presentation/content/content_home.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Quantas vezes o formulário nasceu (initState).
int formBuilds = 0;

void loadPtTranslations() {
  final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync()) as Map<String, dynamic>;
  Localization.load(const Locale('pt'), translations: Translations(json));
}

class _Menus implements MenuRepository {
  @override
  Future<Either<Failure, List<MenuModule>>> getMenus() async => const Right([
        MenuModule(id: 1, description: 'Cadastros', interfaces: [
          MenuInterface(id: 7, description: 'Clientes'),
          MenuInterface(id: 8, description: 'Fornecedores'),
        ]),
        MenuModule(id: 2, description: 'Financeiro', interfaces: [MenuInterface(id: 9, description: 'Boletos')]),
      ]);
}

MenuBloc buildMenuBloc() => MenuBloc(usecase: GetMenusUsecase(repository: _Menus()))..add(const MenuLoadRequested());

/// Formulário com a forma do da fábrica: casca com barra própria + campo com controller no estado da tela.
class FormLike extends StatefulWidget {
  const FormLike({super.key});
  @override
  State<FormLike> createState() => _FormLikeState();
}

class _FormLikeState extends State<FormLike> {
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    formBuilds++;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SetesFormShell(
        title: 'Cliente',
        onBack: () {},
        onSave: () {},
        child: Padding(padding: const EdgeInsets.all(16), child: TextField(key: const ValueKey('name'), controller: _name)),
      );
}

class _HomeLike extends Module {
  _HomeLike(this.shell);
  final Widget Function() shell;

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, __) => shell(), children: [ChildRoute('/customers', child: (_, __) => const FormLike())]),
      ];
}

class _Root extends Module {
  _Root(this.shell);
  final Widget Function() shell;
  @override
  List<ModularRoute> get routes => [ModuleRoute('/home', module: _HomeLike(shell))];
}

/// Sobe o app em `/home/customers` (o formulário aberto no `RouterOutlet` do shell) numa janela de [size].
Future<void> bootShell(WidgetTester tester, {required Size size, required Widget Function() shell}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  formBuilds = 0;
  Modular.setInitialRoute('/home/customers');
  await tester.pumpWidget(ModularApp(
    module: _Root(shell),
    child: MaterialApp.router(routeInformationParser: Modular.routeInformationParser, routerDelegate: Modular.routerDelegate),
  ));
  await tester.pumpAndSettle();
}

/// Deixa as transições do shell (barra, gaveta, coluna) acabarem — sem `pumpAndSettle` (ver o topo).
Future<void> settleShell(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> resizeShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await settleShell(tester);
}

Future<void> tearDownShell(WidgetTester tester, MenuBloc bloc) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(bloc.close);
}

/// Menu ao lado (área larga): a coluna de módulos está na tela e não há ☰.
bool sideMenuShown() => find.text('Cadastros').evaluate().isNotEmpty && find.byIcon(Icons.menu).evaluate().isEmpty;

/// Logomarca de teste com a largura dada. ⚠️ Recebe toque como a `Image` real (que absorve o clique — por isso cobria o ☰ na
/// produção); um `SizedBox` vazio deixa o toque passar e esconderia o bug.
Widget testLogo(double width) =>
    ColoredBox(color: const Color(0xFF0B5394), child: SizedBox(width: width, height: 32));

/// O shell dos testes: o `ContentHome` real com a identidade (logo, usuário) trocada por peças com as larguras dadas.
ContentHome testShell(MenuBloc bloc, {Widget? logo, Widget? barAccount}) => ContentHome(
      bloc: bloc,
      logo: logo ?? testLogo(32),
      barAccount: barAccount ?? const SizedBox(width: 64, height: 40),
      menuFooter: const SizedBox(height: 88),
    );
