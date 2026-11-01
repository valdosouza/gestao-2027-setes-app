import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// Interface (tela) ATUAL — carrega os privilégios que o /api/core/menus
/// devolve por interface (decisão 21 da Fase 1: os privilégios ligam/desligam
/// AÇÕES nas telas; VISUALIZAR decide o menu).
///
/// D-PV17 (Valdo 2026-10-18/20 — `prompt_privilegios_interfaces.md`): a
/// interface de um botão é a do MÓDULO da tela aberta. Navegar entre módulos
/// (o "Devolver" do pedido → `/home/order-returns/`, a engrenagem → o painel
/// de configurações, a aba 'R' hospedada) troca a interface pelo ITEM DO MENU
/// da tela de destino (`bindRoute`, chamado pelo shell a cada navegação);
/// SEM o item no menu carregado, `can` = FALSO — o usuário não tem a tela.
///
/// A fonte é o MENU do usuário (`menu`, carregado pelo `MenuBloc`): admin e
/// super recebem o catálogo inteiro de cada tela; o regular, só o concedido.
/// Enquanto o menu NÃO chegou (deep link antes do `/menus`, testes) o helper
/// LIBERA — quem decide de verdade é a API (403 PRIVILEGE_REQUIRED). Limite
/// conhecido: a tela montada nessa janela só reconsulta no próximo rebuild.
///
/// É só UX: a API aplica o privilégio na rota (guarda por roteador e guardas
/// de ação) e responde 403 se a tela mostrar o botão a quem não pode.
class CurrentInterface {
  CurrentInterface._();

  /// Item do menu da tela atual (null = desconhecido).
  static MenuInterface? value;

  /// Menu carregado (achatado); null = ainda não chegou.
  static Map<String, MenuInterface>? _menu;

  /// Último caminho ligado — o menu que chega depois religa a tela aberta.
  static String? _lastPath;
  static String? _lastInterfaceKey;

  /// Quem quiser reagir à troca de interface (o shell, telas longas).
  static final ValueNotifier<MenuInterface?> listenable = ValueNotifier(null);

  static bool get menuLoaded => _menu != null;

  /// Recebe o menu carregado (módulos → interfaces) e religa a tela aberta.
  static set menu(List<MenuModule>? modules) {
    if (modules == null) {
      _menu = null;
      return;
    }
    final flat = <String, MenuInterface>{};
    for (final module in modules) {
      for (final item in module.interfaces) {
        final key = item.i18nKey;
        if (key != null && key.isNotEmpty) flat.putIfAbsent(key, () => item);
      }
    }
    _menu = flat;
    if (_lastPath != null) bindRoute(_lastPath!, interfaceKey: _lastInterfaceKey);
  }

  /// Item do menu pela chave da interface (null = o usuário não tem a tela).
  static MenuInterface? byKey(String? key) =>
      key == null ? null : _menu?[key];

  /// Chave do módulo de um caminho `/home/<chave>/...` (null fora da casa).
  static String? moduleKeyOf(String path) {
    final segments = Uri.parse(path).path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length < 2 || segments.first != 'home') return null;
    return segments[1];
  }

  /// Liga a tela aberta ao item do menu do SEU módulo (D-PV17). [interfaceKey]
  /// força outra chave — a "Configurações Gerais", que não tem módulo e abre
  /// o painel de configurações filtrado nela.
  static void bindRoute(String path, {String? interfaceKey}) {
    _lastPath = path;
    _lastInterfaceKey = interfaceKey;
    final key = interfaceKey ?? moduleKeyOf(path);
    if (key == null) return; // fora de /home/<módulo> (login, welcome): mantém
    if (_menu == null) return; // menu ainda não chegou: liga quando chegar
    _set(_menu![key]);
  }

  static void _set(MenuInterface? item) {
    value = item;
    listenable.value = item;
  }

  /// O usuário tem o privilégio na tela ATUAL? Nome LITERAL do catálogo.
  static bool can(String privilege) {
    final current = value;
    if (current != null) return current.can(privilege);
    // D-PV17: menu carregado e a tela não está nele → falso. Menu ausente
    // (deep link antes do /menus, testes) → libera; a API decide.
    return _menu == null;
  }

  /// Testes / logout: esquece menu e tela.
  static void reset() {
    _menu = null;
    _lastPath = null;
    _lastInterfaceKey = null;
    _set(null);
  }
}
