import 'package:flutter_modular/flutter_modular.dart';

import '../shared/http/api_client.dart';
import '../shared/storage/local_prefs.dart';
import 'data/datasource/auth_remote_datasource.dart';
import 'data/repository/auth_repository_impl.dart';
import 'domain/repository/auth_repository.dart';
import 'domain/usecase/change_password_usecase.dart';
import 'domain/usecase/login_usecase.dart';
import 'domain/usecase/recovery_password_usecase.dart';
import 'domain/usecase/select_institution_usecase.dart';
import 'presentation/bloc/auth_bloc.dart';
import 'presentation/page/change_password_page.dart';
import 'presentation/page/login_page.dart';
import 'presentation/page/recovery_password_page.dart';
import 'presentation/page/select_institution_page.dart';

/// Módulo de autenticação COMPLETO no core (decisão 25 — modelo
/// GestaoERPApps): web e apps Android reutilizam este módulo inteiro.
///
/// Contrato com o app hospedeiro:
/// - binds de `ApiClient` e `LocalPrefs` no módulo raiz do app
/// - rota `/home/` definida no app (destino pós-login)
/// - chaves de tradução `auth.*` nos assets do app (decisão 13)
class AuthModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<AuthRemoteDatasource>(
            (i) => AuthRemoteDatasource(client: i.get<ApiClient>())),
        Bind.lazySingleton<AuthRepository>(
            (i) => AuthRepositoryImpl(datasource: i.get<AuthRemoteDatasource>())),
        Bind.factory<LoginUsecase>(
            (i) => LoginUsecase(repository: i.get<AuthRepository>())),
        Bind.factory<SelectInstitutionUsecase>(
            (i) => SelectInstitutionUsecase(repository: i.get<AuthRepository>())),
        Bind.factory<RecoveryPasswordUsecase>(
            (i) => RecoveryPasswordUsecase(repository: i.get<AuthRepository>())),
        Bind.factory<ChangePasswordUsecase>(
            (i) => ChangePasswordUsecase(repository: i.get<AuthRepository>())),
        Bind.singleton<AuthBloc>((i) => AuthBloc(
              loginUsecase: i.get<LoginUsecase>(),
              selectUsecase: i.get<SelectInstitutionUsecase>(),
              recoveryUsecase: i.get<RecoveryPasswordUsecase>(),
              changePasswordUsecase: i.get<ChangePasswordUsecase>(),
              apiClient: i.get<ApiClient>(),
              localPrefs: i.get<LocalPrefs>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/login', child: (_, __) => const LoginPage()),
        ChildRoute('/select-institution', child: (_, __) => const SelectInstitutionPage()),
        // Recuperação/alteração de senha (fluxo weberpsetes)
        ChildRoute('/recovery-password', child: (_, __) => const RecoveryPasswordPage()),
        ChildRoute('/change-password', child: (_, __) => const ChangePasswordPage()),
      ];
}
