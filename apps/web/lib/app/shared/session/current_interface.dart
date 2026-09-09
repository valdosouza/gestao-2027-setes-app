import 'package:core/core.dart';

/// Interface (tela) ATUAL escolhida no menu — carrega os privilégios que o
/// /api/core/menus devolve por interface (decisão 21 da Fase 1: os
/// privilégios ligam/desligam AÇÕES nas telas; VISUALIZAR decide o menu).
///
/// Primeiro consumidor: "Cancelar nota" no pedido faturado (D12 do
/// cancelamento, 2026-09-08 — privilégio CANCELAR, id 7). É só UX: a API
/// aplica o privilégio na rota (guard require-privilege) e responde 403
/// PRIVILEGE_REQUIRED se a tela mostrar o botão a quem não pode.
///
/// Sem interface conhecida (deep link, teste) o helper LIBERA — quem
/// decide de verdade é a API.
class CurrentInterface {
  CurrentInterface._();

  static MenuInterface? value;

  static bool can(String privilege) => value?.can(privilege) ?? true;
}
