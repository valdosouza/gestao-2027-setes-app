import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../shared/http/api_client.dart';
import '../../../shared/storage/local_prefs.dart';
import '../../domain/entity/auth_session.dart';
import '../../domain/usecase/change_password_usecase.dart';
import '../../domain/usecase/login_usecase.dart';
import '../../domain/usecase/recovery_password_usecase.dart';
import '../../domain/usecase/select_institution_usecase.dart';

// ---------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
    this.keepConnected = false,
  });
  final String email;
  final String password;

  /// Marcado: o JWT persiste no dispositivo (sobrevive a refresh/fechar,
  /// pelas 24h do token). Desmarcado: sessão só em memória.
  final bool keepConnected;
  @override
  List<Object?> get props => [email, password, keepConnected];
}

class AuthInstitutionSelected extends AuthEvent {
  const AuthInstitutionSelected({required this.institutionId, required this.setAsDefault});
  final int institutionId;

  /// Decisão 15: o padrão só pré-marca a opção — gravado localmente.
  final bool setAsDefault;
  @override
  List<Object?> get props => [institutionId, setAsDefault];
}

/// "Esqueci minha senha": pede o código por e-mail (fluxo weberpsetes).
class AuthRecoveryRequested extends AuthEvent {
  const AuthRecoveryRequested({required this.email});
  final String email;
  @override
  List<Object?> get props => [email];
}

/// Alteração com o código recebido por e-mail. [email] permite chegar
/// direto pelo link do e-mail (sessão nova, sem recuperação pendente).
class AuthChangePasswordRequested extends AuthEvent {
  const AuthChangePasswordRequested({
    required this.code,
    required this.newPassword,
    this.email,
  });
  final String code;
  final String newPassword;
  final String? email;
  @override
  List<Object?> get props => [code, newPassword, email];
}

// ---------------------------------------------------------------------
// States
// ---------------------------------------------------------------------

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// N institutions: mostrar a tela de escolha com o padrão pré-selecionado.
class AuthNeedsSelection extends AuthState {
  const AuthNeedsSelection({required this.session, this.defaultInstitutionId});
  final AuthSession session;
  final int? defaultInstitutionId;
  @override
  List<Object?> get props => [session, defaultInstitutionId];
}

/// JWT final emitido — direto para a home.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.token});
  final String token;
  @override
  List<Object?> get props => [token];
}

class AuthError extends AuthState {
  const AuthError({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Código de recuperação solicitado — UI navega para a tela de alteração.
class AuthRecoveryEmailSent extends AuthState {
  const AuthRecoveryEmailSent({required this.email});
  final String email;
  @override
  List<Object?> get props => [email];
}

/// Senha alterada com sucesso — UI volta ao login.
class AuthPasswordChanged extends AuthState {}

// ---------------------------------------------------------------------
// Bloc — workflow de autenticação do prompt (seção Workflow 1).
// Vive no core (decisão 25): reusado por web e apps Android.
// ---------------------------------------------------------------------

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this.loginUsecase,
    required this.selectUsecase,
    required this.recoveryUsecase,
    required this.changePasswordUsecase,
    required this.apiClient,
    required this.localPrefs,
  }) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLogin);
    on<AuthInstitutionSelected>(_onSelect);
    on<AuthRecoveryRequested>(_onRecovery);
    on<AuthChangePasswordRequested>(_onChangePassword);
  }

  final LoginUsecase loginUsecase;
  final SelectInstitutionUsecase selectUsecase;
  final RecoveryPasswordUsecase recoveryUsecase;
  final ChangePasswordUsecase changePasswordUsecase;
  final ApiClient apiClient;
  final LocalPrefs localPrefs;

  AuthSession? _pendingSession;
  String? _recoveryEmail;
  bool _keepConnected = false;

  /// E-mail da recuperação em andamento (pré-preenche a tela de alteração).
  String? get recoveryEmail => _recoveryEmail;

  /// ApiClient sempre recebe o token (memória); a persistência no
  /// dispositivo depende do "Manter conectado" escolhido no login.
  Future<void> _setSession(String token) async {
    apiClient.token = token;
    await localPrefs.setSessionToken(_keepConnected ? token : null);
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    _keepConnected = event.keepConnected;
    await localPrefs.setKeepConnected(event.keepConnected);
    final result = await loginUsecase(event.email, event.password);
    await result.fold(
      (failure) async => emit(AuthError(message: failure.message)),
      (session) async {
        if (session.needsSelection) {
          _pendingSession = session;
          final defaultId = await localPrefs.getDefaultInstitutionId();
          emit(AuthNeedsSelection(session: session, defaultInstitutionId: defaultId));
        } else {
          await _setSession(session.token!);
          emit(AuthAuthenticated(token: session.token!));
        }
      },
    );
  }

  Future<void> _onSelect(AuthInstitutionSelected event, Emitter<AuthState> emit) async {
    final selectionToken = _pendingSession?.selectionToken;
    if (selectionToken == null) {
      emit(const AuthError(message: 'Sessão de seleção expirada — faça login novamente'));
      return;
    }
    emit(AuthLoading());

    if (event.setAsDefault) {
      await localPrefs.setDefaultInstitutionId(event.institutionId);
    }

    final result = await selectUsecase(selectionToken, event.institutionId);
    await result.fold(
      (failure) async => emit(AuthError(message: failure.message)),
      (token) async {
        await _setSession(token);
        emit(AuthAuthenticated(token: token));
      },
    );
  }

  Future<void> _onRecovery(AuthRecoveryRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await recoveryUsecase(event.email);
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) {
        _recoveryEmail = event.email;
        emit(AuthRecoveryEmailSent(email: event.email));
      },
    );
  }

  Future<void> _onChangePassword(
      AuthChangePasswordRequested event, Emitter<AuthState> emit) async {
    final email = (event.email?.isNotEmpty ?? false) ? event.email : _recoveryEmail;
    if (email == null || email.isEmpty) {
      emit(const AuthError(message: 'Informe o e-mail da conta'));
      return;
    }
    emit(AuthLoading());
    final result = await changePasswordUsecase(email, event.code, event.newPassword);
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) {
        _recoveryEmail = null;
        emit(AuthPasswordChanged());
      },
    );
  }
}
