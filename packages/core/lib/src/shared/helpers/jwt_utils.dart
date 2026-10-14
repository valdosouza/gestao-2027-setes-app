import 'dart:convert';

/// O `exp` (segundos UTC) do JWT, SEM validar assinatura (isso é papel do
/// backend) — `null` quando o token não é um JWT legível ou não traz `exp`.
/// D-F219 (Valdo 2026-10-14): separa "o relógio deste aparelho já passou do
/// exp" (aviso de data/hora) de "o token nem é legível" (resposta ilegível).
int? jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    return (payload['exp'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

/// Verifica a expiração do JWT SEM validar assinatura (isso é papel do
/// backend) — serve só para não reutilizar sessão vencida no cliente.
bool isJwtExpired(String token) {
  final exp = jwtExpiry(token);
  if (exp == null) return true;
  return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
}
