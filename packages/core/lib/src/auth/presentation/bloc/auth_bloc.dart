import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../shared/http/api_client.dart';
import '../../../shared/storage/local_prefs.dart';
import '../../domain/entity/auth_session.dart';
import '../../domain/usecase/login_usecase.dart';
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
  const AuthLoginRequested({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class AuthInstitutionSelected extends AuthEvent {
  const AuthInstitutionSelected({required this.institutionId, required this.setAsDefault});
  final int institutionId;

  /// Decisão 15: o padrão só pré-marca a opção — gravado localmente.
  final bool setAsDefault;
  @override
  List<Object?> get props => [institutionId, setAsDefault];
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

// ---------------------------------------------------------------------
// Bloc — workflow de autenticação do prompt (seção Workflow 1).
// Vive no core (decisão 25): reusado por web e apps Android.
// ---------------------------------------------------------------------

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required this.loginUsecase,
    required this.selectUsecase,
    required this.apiClient,
    required this.localPrefs,
  }) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLogin);
    on<AuthInstitutionSelected>(_onSelect);
  }

  final LoginUsecase loginUsecase;
  final SelectInstitutionUsecase selectUsecase;
  final ApiClient apiClient;
  final LocalPrefs localPrefs;

  AuthSession? _pendingSession;

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await loginUsecase(event.email, event.password);
    await result.fold(
      (failure) async => emit(AuthError(message: failure.message)),
      (session) async {
        if (session.needsSelection) {
          _pendingSession = session;
          final defaultId = await localPrefs.getDefaultInstitutionId();
          emit(AuthNeedsSelection(session: session, defaultInstitutionId: defaultId));
        } else {
          apiClient.token = session.token;
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
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (token) {
        apiClient.token = token;
        emit(AuthAuthenticated(token: token));
      },
    );
  }
}
