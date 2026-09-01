import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/object_establishment.dart';
import '../../domain/usecase/establishment_get.dart';
import '../../domain/usecase/establishment_put.dart';

part 'establishment_event.dart';
part 'establishment_state.dart';

/// Orquestra a tela "Meu Estabelecimento" — CRUD comum SEM lista (parecer
/// setes-conceito 2026-08-25): a cardinalidade 1 é garantida pela API via
/// token, não pela UI. Molde de carregamento: CashierBloc (carrega direto
/// no Started, sem passar por RegisterSearchPage) — mas SEM máquina de
/// estados de sessão, é só get/put de um registro.
class EstablishmentBloc extends Bloc<EstablishmentEvent, EstablishmentState> {
  EstablishmentBloc({required this.get, required this.put})
      : super(const EstablishmentPanelState(loading: true)) {
    on<EstablishmentStarted>((event, emit) => _load(emit));
    on<EstablishmentDraftChanged>(_onDraftChanged);
    on<EstablishmentSaveRequested>(_onSaveRequested);
  }

  final EstablishmentGet get;
  final EstablishmentPut put;

  Future<void> _load(Emitter<EstablishmentState> emit) async {
    emit(const EstablishmentPanelState(loading: true));
    final result = await get();
    result.fold(
      (failure) {
        emit(EstablishmentActionFailure(failure));
        emit(const EstablishmentPanelState());
      },
      (establishment) =>
          emit(EstablishmentPanelState(draft: establishment)),
    );
  }

  void _onDraftChanged(
      EstablishmentDraftChanged event, Emitter<EstablishmentState> emit) {
    emit(EstablishmentPanelState(draft: event.draft));
  }

  Future<void> _onSaveRequested(
      EstablishmentSaveRequested event, Emitter<EstablishmentState> emit) async {
    emit(EstablishmentPanelState(draft: event.draft, saving: true));
    final result = await put(event.draft);
    await result.fold(
      (failure) async {
        emit(EstablishmentActionFailure(failure));
        emit(EstablishmentPanelState(draft: event.draft));
      },
      (updated) async {
        emit(const EstablishmentActionSuccess('register.saved'));
        emit(EstablishmentPanelState(draft: updated));
      },
    );
  }
}
