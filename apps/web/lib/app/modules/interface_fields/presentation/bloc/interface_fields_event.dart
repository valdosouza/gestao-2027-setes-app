part of 'interface_fields_bloc.dart';

sealed class InterfaceFieldsEvent extends Equatable {
  const InterfaceFieldsEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a vitrine (também usado na abertura da página).
class InterfaceFieldsVitrineRequested extends InterfaceFieldsEvent {
  const InterfaceFieldsVitrineRequested(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

/// Abre a lista de campos de uma interface ADQUIRIDA.
class InterfaceFieldsInterfaceOpened extends InterfaceFieldsEvent {
  const InterfaceFieldsInterfaceOpened(this.iface);
  final InterfaceVitrineEntity iface;

  @override
  List<Object?> get props => [iface];
}

/// Volta da lista de campos para a vitrine.
class InterfaceFieldsBackToVitrine extends InterfaceFieldsEvent {
  const InterfaceFieldsBackToVitrine();
}

/// Salva a config de UM campo (caption/required/mask — decisão 3).
class InterfaceFieldsFieldSaveRequested extends InterfaceFieldsEvent {
  const InterfaceFieldsFieldSaveRequested({
    required this.fieldName,
    this.caption,
    this.required = false,
    this.mask,
  });

  final String fieldName;
  final String? caption;
  final bool required;
  final String? mask;

  @override
  List<Object?> get props => [fieldName, caption, required, mask];
}
