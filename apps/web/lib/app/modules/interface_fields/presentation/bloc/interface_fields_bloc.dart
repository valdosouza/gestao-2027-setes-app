import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../../domain/usecase/interface_fields_getfields.dart';
import '../../domain/usecase/interface_fields_getvitrine.dart';
import '../../domain/usecase/interface_fields_savefield.dart';

part 'interface_fields_event.dart';
part 'interface_fields_state.dart';

/// Orquestra o painel de campos configuráveis (decisão 6 da Fase 2):
/// vitrine de interfaces ↔ campos da interface aberta; salvar config de um
/// campo recarrega a lista (a API invalida o cache da config resolvida).
class InterfaceFieldsBloc
    extends Bloc<InterfaceFieldsEvent, InterfaceFieldsState> {
  InterfaceFieldsBloc({
    required this.getVitrine,
    required this.getFields,
    required this.saveField,
  }) : super(const InterfaceFieldsVitrineState(loading: true)) {
    on<InterfaceFieldsVitrineRequested>(_onVitrineRequested);
    on<InterfaceFieldsInterfaceOpened>(_onInterfaceOpened);
    on<InterfaceFieldsBackToVitrine>((event, emit) => _reloadVitrine(emit));
    on<InterfaceFieldsFieldSaveRequested>(_onFieldSaveRequested);
  }

  final InterfaceFieldsGetvitrine getVitrine;
  final InterfaceFieldsGetfields getFields;
  final InterfaceFieldsSavefield saveField;

  /// Último filtro aplicado — recarga ao voltar da lista de campos.
  String _filter = '';

  Future<void> _onVitrineRequested(InterfaceFieldsVitrineRequested event,
      Emitter<InterfaceFieldsState> emit) async {
    _filter = event.filter;
    await _reloadVitrine(emit);
  }

  Future<void> _reloadVitrine(Emitter<InterfaceFieldsState> emit) async {
    emit(const InterfaceFieldsVitrineState(loading: true));
    final result = await getVitrine(_filter);
    result.fold(
      (failure) {
        emit(InterfaceFieldsActionFailure(failure.message));
        emit(const InterfaceFieldsVitrineState());
      },
      (items) => emit(InterfaceFieldsVitrineState(items: items)),
    );
  }

  Future<void> _onInterfaceOpened(InterfaceFieldsInterfaceOpened event,
      Emitter<InterfaceFieldsState> emit) async {
    await _reloadFields(event.iface, emit);
  }

  Future<void> _reloadFields(InterfaceVitrineEntity iface,
      Emitter<InterfaceFieldsState> emit) async {
    emit(InterfaceFieldsFieldsState(iface: iface, loading: true));
    final result = await getFields(iface.id);
    result.fold(
      (failure) {
        emit(InterfaceFieldsActionFailure(failure.message));
        emit(const InterfaceFieldsVitrineState());
      },
      (fields) => emit(InterfaceFieldsFieldsState(iface: iface, fields: fields)),
    );
  }

  Future<void> _onFieldSaveRequested(InterfaceFieldsFieldSaveRequested event,
      Emitter<InterfaceFieldsState> emit) async {
    final current = state;
    if (current is! InterfaceFieldsFieldsState) return;

    emit(InterfaceFieldsFieldsState(
        iface: current.iface, fields: current.fields, saving: true));
    final result = await saveField(
      interfaceId: current.iface.id,
      fieldName: event.fieldName,
      caption: event.caption,
      required: event.required,
      mask: event.mask,
    );
    await result.fold(
      (failure) async {
        emit(InterfaceFieldsActionFailure(failure.message));
        emit(InterfaceFieldsFieldsState(
            iface: current.iface, fields: current.fields));
      },
      (_) async {
        emit(const InterfaceFieldsActionSuccess('forms.interfaceFields.saved'));
        await _reloadFields(current.iface, emit);
      },
    );
  }
}
