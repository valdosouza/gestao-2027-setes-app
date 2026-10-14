import 'dart:convert';

Map<String, dynamic>? _jwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    return jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

int? _jwtSeconds(String token, String claim) {
  try {
    return (_jwtPayload(token)?[claim] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

/// O `exp` (segundos UTC) do JWT, SEM validar assinatura (isso é papel do
/// backend) — `null` quando o token não é um JWT legível ou não traz `exp`.
/// D-F219 (Valdo 2026-10-14): separa "o relógio deste aparelho já passou do
/// exp" (aviso de data/hora) de "o token nem é legível" (resposta ilegível).
int? jwtExpiry(String token) => _jwtSeconds(token, 'exp');

/// O `iat` (segundos UTC, a hora do SERVIDOR na emissão) do JWT — `null` sem
/// `iat` legível. LF-ADV-01 (Valdo 2026-10-14): com ele se distingue o relógio
/// do aparelho errado (`agora` longe do `iat`) do token que o servidor já
/// emitiu vencido (`agora` perto do `iat`, TTL mal configurado).
int? jwtIssuedAt(String token) => _jwtSeconds(token, 'iat');

/// Verifica a expiração do JWT SEM validar assinatura (isso é papel do
/// backend) — serve só para não reutilizar sessão vencida no cliente.
bool isJwtExpired(String token) {
  final exp = jwtExpiry(token);
  if (exp == null) return true;
  return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
}
