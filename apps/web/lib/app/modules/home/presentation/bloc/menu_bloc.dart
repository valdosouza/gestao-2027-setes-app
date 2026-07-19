import 'package:bloc/bloc.dart';
import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class MenuEvent extends Equatable {
  const MenuEvent();
  @override
  List<Object?> get props => [];
}

class MenuLoadRequested extends MenuEvent {
  const MenuLoadRequested();
}

class MenuModuleSelected extends MenuEvent {
  const MenuModuleSelected({required this.index});
  final int index;
  @override
  List<Object?> get props => [index];
}

class MenuInterfaceSelected extends MenuEvent {
  const MenuInterfaceSelected({required this.interfaceItem});
  final MenuInterface interfaceItem;
  @override
  List<Object?> get props => [interfaceItem];
}

// States
abstract class MenuState extends Equatable {
  const MenuState();
  @override
  List<Object?> get props => [];
}

class MenuInitial extends MenuState {}

class MenuLoading extends MenuState {}

class MenuLoaded extends MenuState {
  const MenuLoaded({
    required this.modules,
    this.selectedModuleIndex,
    this.selectedInterface,
  });

  final List<MenuModule> modules;
  final int? selectedModuleIndex;

  /// Interface aberta no frame de renderização (decisão 21).
  final MenuInterface? selectedInterface;

  MenuModule? get selectedModule => selectedModuleIndex != null &&
          selectedModuleIndex! >= 0 &&
          selectedModuleIndex! < modules.length
      ? modules[selectedModuleIndex!]
      : null;

  MenuLoaded copyWith({int? selectedModuleIndex, MenuInterface? selectedInterface}) =>
      MenuLoaded(
        modules: modules,
        selectedModuleIndex: selectedModuleIndex ?? this.selectedModuleIndex,
        selectedInterface: selectedInterface ?? this.selectedInterface,
      );

  @override
  List<Object?> get props => [modules, selectedModuleIndex, selectedInterface];
}

/// Falha na carga dos menus. Carrega o [failure] INTEIRO (Framework de
/// Mensagens, R7): a natureza (técnico × corrigível) deriva do desfecho na
/// ponte de feedback — a tela mostra o dialog e mantém o corpo neutro.
class MenuError extends MenuState {
  const MenuError({required this.failure});
  final Failure failure;

  /// Mensagem (pode ser chave i18n `core.errors.*` — a UI traduz).
  String get message => failure.message;

  @override
  List<Object?> get props => [failure];
}

/// Menus 100% via GET /api/core/menus (decisões 1, 21) — nada hard-coded.
class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc({required this.usecase}) : super(MenuInitial()) {
    on<MenuLoadRequested>(_onLoad);
    on<MenuModuleSelected>(_onModuleSelected);
    on<MenuInterfaceSelected>(_onInterfaceSelected);
  }

  final GetMenusUsecase usecase;

  Future<void> _onLoad(MenuLoadRequested event, Emitter<MenuState> emit) async {
    emit(MenuLoading());
    final result = await usecase();
    result.fold(
      (failure) => emit(MenuError(failure: failure)),
      (modules) => emit(MenuLoaded(modules: modules)),
    );
  }

  void _onModuleSelected(MenuModuleSelected event, Emitter<MenuState> emit) {
    final current = state;
    if (current is MenuLoaded) {
      emit(MenuLoaded(modules: current.modules, selectedModuleIndex: event.index));
    }
  }

  void _onInterfaceSelected(MenuInterfaceSelected event, Emitter<MenuState> emit) {
    final current = state;
    if (current is MenuLoaded) {
      emit(current.copyWith(selectedInterface: event.interfaceItem));
    }
  }
}
