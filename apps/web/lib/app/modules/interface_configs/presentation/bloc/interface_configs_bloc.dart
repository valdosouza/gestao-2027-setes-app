import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/interface_config/entity/interface_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../../domain/usecase/interface_configs_getconfigs.dart';
import '../../domain/usecase/interface_configs_getvitrine.dart';
import '../../domain/usecase/interface_configs_savevalue.dart';

part 'interface_configs_event.dart';
part 'interface_configs_state.dart';

/// Orquestra o painel de configurações do sistema (Framework de
/// Configurações, decisões 7 e 9): vitrine de interfaces ↔ configs da
/// interface aberta; salvar um valor recarrega a lista (a API invalida o
/// cache da config resolvida). O atalho da engrenagem (decisão 11) entra
/// por [InterfaceConfigsOpenByKey] — painel já filtrado na interface.
class InterfaceConfigsBloc
    extends Bloc<InterfaceConfigsEvent, InterfaceConfigsState> {
  InterfaceConfigsBloc({
    required this.getVitrine,
    required this.getConfigs,
    required this.saveValue,
  }) : super(const InterfaceConfigsVitrineState(loading: true)) {
    on<InterfaceConfigsVitrineRequested>(_onVitrineRequested);
    on<InterfaceConfigsInterfaceOpened>(_onInterfaceOpened);
    on<InterfaceConfigsOpenByKey>(_onOpenByKey);
    on<InterfaceConfigsBackToVitrine>((event, emit) => _reloadVitrine(emit));
    on<InterfaceConfigsValueSaveRequested>(_onValueSaveRequested);
  }

  final InterfaceConfigsGetvitrine getVitrine;
  final InterfaceConfigsGetconfigs getConfigs;
  final InterfaceConfigsSavevalue saveValue;

  /// Último filtro aplicado — recarga ao voltar da lista de configs.
  String _filter = '';

  Future<void> _onVitrineRequested(InterfaceConfigsVitrineRequested event,
      Emitter<InterfaceConfigsState> emit) async {
    _filter = event.filter;
    await _reloadVitrine(emit);
  }

  Future<void> _reloadVitrine(Emitter<InterfaceConfigsState> emit) async {
    emit(const InterfaceConfigsVitrineState(loading: true));
    final result = await getVitrine(_filter);
    result.fold(
      (failure) {
        emit(InterfaceConfigsActionFailure(failure));
        emit(const InterfaceConfigsVitrineState());
      },
      (items) => emit(InterfaceConfigsVitrineState(items: items)),
    );
  }

  Future<void> _onInterfaceOpened(InterfaceConfigsInterfaceOpened event,
      Emitter<InterfaceConfigsState> emit) async {
    await _reloadConfigs(event.iface, emit);
  }

  /// Atalho contextual (decisão 11): a engrenagem da tela de LISTA conhece a
  /// CHAVE do módulo — a vitrine resolve a interface e abre já filtrado.
  Future<void> _onOpenByKey(InterfaceConfigsOpenByKey event,
      Emitter<InterfaceConfigsState> emit) async {
    emit(const InterfaceConfigsVitrineState(loading: true));
    final result = await getVitrine('');
    await result.fold(
      (failure) async {
        emit(InterfaceConfigsActionFailure(failure));
        emit(const InterfaceConfigsVitrineState());
      },
      (items) async {
        InterfaceVitrineEntity? match;
        for (final item in items) {
          if (item.i18nKey == event.moduleKey) {
            match = item;
            break;
          }
        }
        if (match != null && match.acquired) {
          await _reloadConfigs(match, emit);
        } else {
          emit(InterfaceConfigsVitrineState(items: items));
        }
      },
    );
  }

  Future<void> _reloadConfigs(InterfaceVitrineEntity iface,
      Emitter<InterfaceConfigsState> emit) async {
    emit(InterfaceConfigsConfigsState(iface: iface, loading: true));
    final result = await getConfigs(iface.id);
    result.fold(
      (failure) {
        emit(InterfaceConfigsActionFailure(failure));
        emit(const InterfaceConfigsVitrineState());
      },
      (configs) =>
          emit(InterfaceConfigsConfigsState(iface: iface, configs: configs)),
    );
  }

  Future<void> _onValueSaveRequested(InterfaceConfigsValueSaveRequested event,
      Emitter<InterfaceConfigsState> emit) async {
    final current = state;
    if (current is! InterfaceConfigsConfigsState) return;

    emit(InterfaceConfigsConfigsState(
        iface: current.iface, configs: current.configs, saving: true));
    final result = await saveValue(
      interfaceId: current.iface.id,
      name: event.name,
      content: event.content,
      asUser: event.asUser,
    );
    await result.fold(
      (failure) async {
        emit(InterfaceConfigsActionFailure(failure));
        emit(InterfaceConfigsConfigsState(
            iface: current.iface, configs: current.configs));
      },
      (_) async {
        emit(const InterfaceConfigsActionSuccess('forms.interfaceConfigs.saved'));
        await _reloadConfigs(current.iface, emit);
      },
    );
  }
}
