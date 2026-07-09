import 'package:flutter_modular/flutter_modular.dart';

import '../../../shared/helpers/jwt_utils.dart';
import '../../../shared/http/api_client.dart';
import '../../../shared/storage/local_prefs.dart';

/// Guarda das rotas autenticadas: no refresh do navegador restaura o JWT
/// persistido (LocalPrefs) para o ApiClient; sessão ausente/vencida →
/// redireciona ao login. Aplicar no ModuleRoute de /home (e futuros).
class SetesAuthGuard extends RouteGuard {
  SetesAuthGuard() : super(redirectTo: '/login');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final client = Modular.get<ApiClient>();

    if (client.token != null && !isJwtExpired(client.token!)) return true;

    final prefs = Modular.get<LocalPrefs>();
    final saved = await prefs.getSessionToken();
    if (saved != null && !isJwtExpired(saved)) {
      client.token = saved;
      return true;
    }

    await prefs.setSessionToken(null); // limpa sessão vencida
    return false;
  }
}
