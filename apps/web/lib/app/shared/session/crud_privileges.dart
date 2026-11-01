import 'current_interface.dart';

/// CRUD da tela ATUAL (D-PV2, Valdo 2026-10-18 —
/// `Infra-IA/prompts/prompt_privilegios_interfaces.md`): o ÚNICO ponto onde a
/// FÁBRICA de cadastros (`RegisterSearchPage`, `RegisterFormPage`,
/// `RegisterFormShell`) pergunta INSERIR/ALTERAR/EXCLUIR. "Novo" ← INSERIR;
/// salvar ← INSERIR (registro novo) ou ALTERAR (edição); excluir ← EXCLUIR.
///
/// Nomes LITERAIS do catálogo (`tb_privilege.description`) — a cerca da D-PV9
/// lê o par estaticamente. As telas de processo (`modules/<m>/`) perguntam
/// direto `CurrentInterface.can('NOME')`, também com o literal.
///
/// É UX: a API confere o mesmo par na guarda por roteador e responde 403
/// PRIVILEGE_REQUIRED a quem a tela mostrou o botão por engano. Admin e super
/// recebem o CATÁLOGO da interface no menu (tudo liberado); sem interface
/// conhecida (deep link, teste) libera — quem decide é a API.
class CrudPrivileges {
  CrudPrivileges._();

  static bool get canInsert => CurrentInterface.can('INSERIR');
  static bool get canUpdate => CurrentInterface.can('ALTERAR');
  static bool get canDelete => CurrentInterface.can('EXCLUIR');

  /// Salvar um registro novo pede INSERIR; salvar a edição pede ALTERAR.
  static bool canSave({required bool creating}) =>
      creating ? canInsert : canUpdate;
}
