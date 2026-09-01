part of 'establishment_bloc.dart';

abstract class EstablishmentEvent extends Equatable {
  const EstablishmentEvent();

  @override
  List<Object?> get props => [];
}

/// Carga inicial — disparado no initState da página (sem lista, decisão
/// setes-conceito 2026-08-25: cardinalidade 1 garantida pela API).
class EstablishmentStarted extends EstablishmentEvent {
  const EstablishmentStarted();
}

/// Edição local do draft (apresentação pura — as abas repassam a fatia
/// editada; o bloc só guarda o estado).
class EstablishmentDraftChanged extends EstablishmentEvent {
  const EstablishmentDraftChanged(this.draft);

  final ObjectEstablishment draft;

  @override
  List<Object?> get props => [draft];
}

class EstablishmentSaveRequested extends EstablishmentEvent {
  const EstablishmentSaveRequested(this.draft);

  final ObjectEstablishment draft;

  @override
  List<Object?> get props => [draft];
}
