import 'dart:convert';

/// Verifica a expiração do JWT SEM validar assinatura (isso é papel do
/// backend) — serve só para não reutilizar sessão vencida no cliente.
bool isJwtExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    final exp = (payload['exp'] as num?)?.toInt();
    if (exp == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
  } catch (_) {
    return true;
  }
}
