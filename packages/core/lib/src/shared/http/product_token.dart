import 'dart:async';

/// O JWT do login vigente NESTE dispositivo — UM para as N APIs do produto
/// (setes-api, nfse-api, a futura nfe-api). D-F138 (= Q-F146 (a), Valdo
/// 2026-10-13 — `prompt_apis_fiscais_isoladas.md` §22.14.3): cada API tem o
/// seu cliente HTTP (base de URL própria), mas TODOS leem o token AQUI a cada
/// requisição — trocar de institution ou sair vale para todos de uma vez
/// (copiar o token em cada cliente deixaria o 2º agindo com o token velho,
/// no estabelecimento errado). Nome espelha o `@shared/auth/product-token` do
/// setes-api e o `productAuth` da nfse-api.
///
/// Expiração GLOBAL: um 401 numa requisição que LEVOU este token, vindo de
/// QUEM EMITIU o token (o setes-api), significa que a sessão morreu — o
/// cliente HTTP chama [expire] e os ouvintes (o app: limpa a sessão salva e
/// volta ao login) agem uma vez. 401 SEM token (login, recuperação de senha)
/// não é expiração: segue para a tela.
///
/// D-F148 (= Q-F160 (a), Valdo 2026-10-13 — gate socrático da F2b, F2B-SOC-01 /
/// F2B-ADV-06): o 401 de uma API que NÃO emitiu o token (a nfse-api — chave de
/// assinatura nova que ela ainda não conhece, institution divergente) não
/// derruba a sessão sozinho: [confirm] pergunta ao EMISSOR ([confirmer] =
/// `GET /api/core/me` no setes-api). Ele recusou → a sessão morreu (expira);
/// ele aceitou → a sessão VIVE e quem chamou diz "o serviço não reconheceu a
/// sessão" (o login não entra em laço por erro de configuração de uma API).
class ProductToken {
  String? _value;
  String? _lastExpired;
  final List<void Function()> _expiredListeners = [];

  /// Pergunta ao EMISSOR do token se a sessão vive (true = vive). Sem ele, o
  /// 401 de qualquer API expira (o comportamento da D-F138).
  Future<bool> Function()? confirmer;

  /// Prazo da pergunta ao emissor (F2B-RG-06/SOCD-03): o `/api/core/me` que não
  /// volta "não prova a morte" — a sessão fica, a tela diz que o serviço não a
  /// reconheceu, e a próxima 401 pergunta de novo (nunca presa à pendurada).
  Duration confirmTimeout = const Duration(seconds: 15);

  /// Confirmação em andamento (vários 401 juntos perguntam UMA vez).
  Future<bool>? _confirming;
  String? _confirmingToken;

  /// O token atual (null = sem sessão).
  String? get value => _value;

  /// Grava o token (vazio vira null).
  set value(String? token) =>
      _value = (token == null || token.isEmpty) ? null : token;

  /// O último token que EXPIROU — o ouvinte só limpa a sessão SALVA se ela for
  /// essa (com várias abas, a aba velha não apaga o login novo da outra —
  /// F2B-ADV-11).
  String? get lastExpired => _lastExpired;

  /// Registra quem reage à expiração (o app: limpar a sessão salva e ir ao
  /// login). Devolve a função que remove o ouvinte.
  void Function() addExpiredListener(void Function() listener) {
    _expiredListeners.add(listener);
    return () => _expiredListeners.remove(listener);
  }

  /// A requisição que levou [sentToken] voltou 401 de quem EMITIU o token. Só
  /// expira se o token ainda é ESSE (um 401 atrasado de uma sessão anterior não
  /// derruba o login novo) — e avisa os ouvintes uma vez. Ouvinte que lança não
  /// cala os outros nem troca o erro da requisição (F2B-ADV-11).
  void expire(String sentToken) {
    if (_value == null || _value != sentToken) return;
    _value = null;
    _lastExpired = sentToken;
    for (final listener in List.of(_expiredListeners)) {
      try {
        listener();
      } catch (_) {
        // isolado: a expiração já aconteceu; o próximo ouvinte é avisado
      }
    }
  }

  /// D-F148: a requisição que levou [sentToken] voltou 401 de uma API que NÃO
  /// emitiu o token. [SessionCheck.stale] = o token já mudou (o 401 é de uma
  /// sessão anterior — nada a fazer); [SessionCheck.dead] = o emissor também
  /// recusou (ou não há [confirmer]) — expirou; [SessionCheck.alive] = o emissor
  /// aceita: a sessão fica (falha do confirmador = não prova a morte = vive).
  Future<SessionCheck> confirm(String sentToken) async {
    if (_value == null || _value != sentToken) return SessionCheck.stale;
    final ask = confirmer;
    if (ask == null) {
      expire(sentToken);
      return SessionCheck.dead;
    }
    final running = _confirmingToken == sentToken ? _confirming : null;
    final pending = running ?? _startConfirm(ask, sentToken);
    final alive = await pending;
    if (alive) return _value == sentToken ? SessionCheck.alive : SessionCheck.stale;
    expire(sentToken);
    return SessionCheck.dead;
  }

  Future<bool> _startConfirm(Future<bool> Function() ask, String sentToken) {
    final done = Completer<bool>();
    _confirming = done.future;
    _confirmingToken = sentToken;
    // Future.sync: o confirmador que lança SÍNCRONO também vira "não prova a morte"
    Future<bool>.sync(ask)
        .timeout(confirmTimeout, onTimeout: () => true)
        .then((alive) => alive, onError: (Object _) => true)
        .then((alive) {
      if (identical(_confirming, done.future)) {
        _confirming = null;
        _confirmingToken = null;
      }
      done.complete(alive);
    });
    return done.future;
  }
}

/// Veredito de [ProductToken.confirm] (D-F148).
enum SessionCheck { alive, dead, stale }
