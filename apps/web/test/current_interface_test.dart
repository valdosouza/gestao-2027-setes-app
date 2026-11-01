// D-PV17 (Valdo 2026-10-18/20 — Infra-IA/prompts/prompt_privilegios_interfaces.md):
// a interface de um botão é a do MÓDULO da tela aberta; navegar entre módulos
// troca o CurrentInterface pelo item do menu da tela de destino; sem o item no
// menu carregado, `can` = falso. Menu ausente (deep link antes do /menus) libera —
// a API decide.

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

MenuInterface _iface(int id, String key, List<String> privileges) =>
    MenuInterface(id: id, description: key, i18nKey: key, privileges: privileges);

final _menu = [
  MenuModule(description: 'Vendas', interfaces: [
    _iface(29, 'orders', ['VISUALIZAR', 'INSERIR', 'ALTERAR']),
    _iface(31, 'order-returns', ['VISUALIZAR']),
  ]),
  MenuModule(description: 'Sistema', interfaces: [
    _iface(10, 'interface-configs', ['VISUALIZAR']),
    _iface(11, 'general-configs', ['VISUALIZAR', 'CONFIGURAR']),
  ]),
];

void main() {
  tearDown(CurrentInterface.reset);

  test('moduleKeyOf lê o módulo de /home/<chave>/… e ignora o resto', () {
    expect(CurrentInterface.moduleKeyOf('/home/orders/'), 'orders');
    expect(CurrentInterface.moduleKeyOf('/home/order-returns/123?x=1'), 'order-returns');
    expect(CurrentInterface.moduleKeyOf('/home/'), isNull);
    expect(CurrentInterface.moduleKeyOf('/login'), isNull);
  });

  test('sem menu: libera (deep link antes do /menus) — a API decide', () {
    CurrentInterface.bindRoute('/home/orders/');
    expect(CurrentInterface.menuLoaded, isFalse);
    expect(CurrentInterface.can('INSERIR'), isTrue);
  });

  test('menu carregado: a rota liga ao item do módulo e os privilégios são os dele', () {
    CurrentInterface.menu = _menu;
    CurrentInterface.bindRoute('/home/orders/');
    expect(CurrentInterface.value?.i18nKey, 'orders');
    expect([CurrentInterface.can('INSERIR'), CurrentInterface.can('EXCLUIR')], [true, false]);
    expect(CurrentInterface.listenable.value?.id, 29);
  });

  test('navegar entre módulos troca a interface (o "Devolver" do pedido abre a Devolução com os privilégios DELA)', () {
    CurrentInterface.menu = _menu;
    CurrentInterface.bindRoute('/home/orders/');
    expect(CurrentInterface.can('INSERIR'), isTrue);
    CurrentInterface.bindRoute('/home/order-returns/');
    expect(CurrentInterface.value?.i18nKey, 'order-returns');
    expect(CurrentInterface.can('INSERIR'), isFalse);
  });

  test('tela fora do menu carregado: can = falso (o usuário não tem a tela)', () {
    CurrentInterface.menu = _menu;
    CurrentInterface.bindRoute('/home/customers/');
    expect(CurrentInterface.value, isNull);
    expect(CurrentInterface.can('VISUALIZAR'), isFalse);
  });

  test('rota fora de /home/<módulo> (welcome, login) não mexe na tela ligada', () {
    CurrentInterface.menu = _menu;
    CurrentInterface.bindRoute('/home/orders/');
    CurrentInterface.bindRoute('/home/');
    expect(CurrentInterface.value?.i18nKey, 'orders');
  });

  test('o menu que chega DEPOIS da navegação religa a tela aberta (F5 em /home/orders/)', () {
    CurrentInterface.bindRoute('/home/orders/');
    expect(CurrentInterface.value, isNull);
    CurrentInterface.menu = _menu;
    expect(CurrentInterface.value?.i18nKey, 'orders');
  });

  test('"Configurações Gerais": o painel abre filtrado nela e a interface dos botões é a DELA (interfaceKey explícita)', () {
    CurrentInterface.menu = _menu;
    CurrentInterface.bindRoute('/home/interface-configs/', interfaceKey: 'general-configs');
    expect(CurrentInterface.value?.i18nKey, 'general-configs');
    expect(CurrentInterface.can('CONFIGURAR'), isTrue);
    CurrentInterface.bindRoute('/home/interface-configs/');
    expect(CurrentInterface.value?.i18nKey, 'interface-configs');
    expect(CurrentInterface.can('CONFIGURAR'), isFalse);
  });

  test('menu nulo (logout) volta ao modo "libera"; reset esquece tudo', () {
    CurrentInterface.menu = _menu;
    CurrentInterface.bindRoute('/home/customers/');
    expect(CurrentInterface.can('VISUALIZAR'), isFalse);
    CurrentInterface.menu = null;
    expect(CurrentInterface.can('VISUALIZAR'), isTrue);
    CurrentInterface.reset();
    expect(CurrentInterface.value, isNull);
    expect(CurrentInterface.menuLoaded, isFalse);
  });
}
