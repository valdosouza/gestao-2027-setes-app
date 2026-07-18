import 'package:flutter/foundation.dart';

/// SessionContext ÚNICO do app (decisão 17 do Framework de Configurações —
/// substituto das variáveis globais GB_* do Delphi).
///
/// - Preenchido a partir do bloco `context` da resposta do login e
///   RE-HIDRATADO via GET /api/core/me na entrada da Home (cobre refresh e
///   troca de institution) — ver HomePage.initState.
/// - Somente LEITURA para as telas (uso é UX apenas, ex.: travar o filtro
///   de vendedor na lista de Clientes); o enforcement é SEMPRE da API.
/// - Limpo no logout / sobrescrito a cada nova sessão.
/// - PROIBIDO variável global solta: valor novo de sessão = campo novo AQUI
///   + resolver em setes-api src/shared/session-context (caminho único).
class SessionContext extends ChangeNotifier {
  bool _isSalesman = false;

  /// O usuário logado é vendedor na institution corrente (tb_salesman —
  /// decisão 15; herança por PK tb_user.id = tb_entity.id = tb_salesman.id).
  bool get isSalesman => _isSalesman;

  /// Aplica o bloco `context` vindo da API (login ou /api/core/me).
  void applyJson(Map<String, dynamic>? json) {
    _isSalesman = json?['isSalesman'] == true;
    notifyListeners();
  }

  void clear() {
    _isSalesman = false;
    notifyListeners();
  }
}
