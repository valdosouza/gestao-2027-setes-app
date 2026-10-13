/// O JWT do login vigente NESTE dispositivo — UM para as N APIs do produto
/// (setes-api, nfse-api, a futura nfe-api). D-F138 (= Q-F146 (a), Valdo
/// 2026-10-13 — `prompt_apis_fiscais_isoladas.md` §22.14.3): cada API tem o
/// seu [ApiClient] (base de URL própria), mas TODOS leem o token AQUI a cada
/// requisição — trocar de institution ou sair vale para todos de uma vez
/// (copiar o token em cada cliente deixaria o 2º agindo com o token velho,
/// no estabelecimento errado). Nome espelha o `@shared/auth/product-token` do
/// setes-api e o `productAuth` da nfse-api.
///
/// Expiração GLOBAL: um 401 numa requisição que LEVOU este token significa
/// que a sessão morreu (expirou, foi trocada a chave, o usuário saiu) — o
/// cliente HTTP chama [expire] e os ouvintes (o app: limpa a sessão salva e
/// volta ao login) agem uma vez. 401 SEM token (login, recuperação de senha)
/// não é expiração: segue para a tela.
class ProductToken {
  String? _value;
  final List<void Function()> _expiredListeners = [];

  /// O token atual (null = sem sessão).
  String? get value => _value;

  /// Grava o token (vazio vira null).
  set value(String? token) =>
      _value = (token == null || token.isEmpty) ? null : token;

  /// Registra quem reage à expiração (o app: limpar a sessão salva e ir ao
  /// login). Devolve a função que remove o ouvinte.
  void Function() addExpiredListener(void Function() listener) {
    _expiredListeners.add(listener);
    return () => _expiredListeners.remove(listener);
  }

  /// A requisição que levou [sentToken] voltou 401. Só expira se o token
  /// ainda é ESSE (um 401 atrasado de uma sessão anterior não derruba o
  /// login novo) — e avisa os ouvintes uma vez.
  void expire(String sentToken) {
    if (_value == null || _value != sentToken) return;
    _value = null;
    for (final listener in List.of(_expiredListeners)) {
      listener();
    }
  }
}
