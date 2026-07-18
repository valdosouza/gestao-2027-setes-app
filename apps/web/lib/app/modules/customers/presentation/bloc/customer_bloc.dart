import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/object_customer.dart';
import '../../domain/usecase/customer_delete.dart';
import '../../domain/usecase/customer_get.dart';
import '../../domain/usecase/customer_getlist.dart';
import '../../domain/usecase/customer_post.dart';
import '../../domain/usecase/customer_put.dart';

part 'customer_event.dart';
part 'customer_state.dart';

/// Orquestra o CRUD de Cliente: alterna pesquisa ↔ formulário e guarda o
/// DRAFT do ObjectCustomer inteiro (skill cadastro-entidade-fiscal.md) —
/// as abas editam fatias via onChanged (CustomerDraftChanged) e salvar é
/// 1 evento com o objeto completo.
///
/// Fase 3 Entidade Única: POST com reused=true vira SnackBar informativo;
/// 409 de papel duplicado (fields[0].field == 'id') vira o one-shot
/// CustomerDuplicateRole — a página oferece abrir em edição (decisão 2).
class CustomerBloc extends Bloc<CustomerEvent, CustomerBlocState> {
  CustomerBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CustomerListState(loading: true)) {
    on<CustomerListRequested>(_onListRequested);
    on<CustomerNewPressed>(_onNewPressed);
    on<CustomerEditPressed>(_onEditPressed);
    on<CustomerDraftChanged>(_onDraftChanged);
    on<CustomerBackToListPressed>((event, emit) => _reload(emit));
    on<CustomerSaveRequested>(_onSaveRequested);
    on<CustomerDeleteRequested>(_onDeleteRequested);
  }

  final CustomerGetlist getlist;
  final CustomerGet get;
  final CustomerPost post;
  final CustomerPut put;
  final CustomerDelete delete;

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  /// Cadastro novo com as pré-seleções do Framework de Configurações
  /// (piloto, decisões 10 e 14) aplicadas sobre o draft padrão.
  void _onNewPressed(CustomerNewPressed event, Emitter<CustomerBlocState> emit) {
    var draft = const ObjectCustomer();
    if (event.personType != null) {
      draft = draft.copyWith(personType: event.personType);
    }
    if (event.consumer != null) {
      draft = draft.copyWith(tax: EntityTaxData(consumer: event.consumer!));
    }
    emit(CustomerFormState(draft: draft, creating: true));
  }

  Future<void> _onListRequested(
      CustomerListRequested event, Emitter<CustomerBlocState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CustomerBlocState> emit) async {
    emit(const CustomerListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(CustomerActionFailure(failure.message));
        emit(const CustomerListState());
      },
      (items) => emit(CustomerListState(items: items)),
    );
  }

  /// Edição: busca o objeto COMPLETO (GET :id) antes de abrir o form.
  Future<void> _onEditPressed(
      CustomerEditPressed event, Emitter<CustomerBlocState> emit) async {
    emit(CustomerListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    result.fold(
      (failure) {
        emit(CustomerActionFailure(failure.message));
        emit(CustomerListState(items: _currentItems));
      },
      (customer) => emit(CustomerFormState(draft: customer, creating: false)),
    );
  }

  List<CustomerListItem> get _currentItems {
    final current = state;
    return current is CustomerListState ? current.items : const [];
  }

  /// As abas editam fatias do draft — o bloc só reemite o form atualizado.
  void _onDraftChanged(
      CustomerDraftChanged event, Emitter<CustomerBlocState> emit) {
    final current = state;
    if (current is! CustomerFormState) return;
    emit(CustomerFormState(draft: event.draft, creating: current.creating));
  }

  /// 409 de papel duplicado carrega o id do registro existente em
  /// fields[0].message (contrato do módulo customers da API).
  int? _duplicateRoleId(Failure failure) {
    if (failure.statusCode != 409) return null;
    final idText = failure.fieldMessage('id');
    return idText != null ? int.tryParse(idText) : null;
  }

  Future<void> _onSaveRequested(
      CustomerSaveRequested event, Emitter<CustomerBlocState> emit) async {
    emit(CustomerFormState(
        draft: event.draft, creating: event.creating, saving: true));

    void onFailure(Failure failure) {
      final existingId = _duplicateRoleId(failure);
      if (existingId != null) {
        emit(CustomerDuplicateRole(existingId));
      } else {
        emit(CustomerActionFailure(failure.message));
      }
      emit(CustomerFormState(draft: event.draft, creating: event.creating));
    }

    if (event.creating) {
      final result = await post(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (postResult) async {
          // reused = a API reaproveitou entity existente (decisões 1 e 9).
          emit(CustomerActionSuccess(postResult.reused
              ? 'forms.customer.reusedEntity'
              : 'register.saved'));
          await _reload(emit);
        },
      );
    } else {
      final result = await put(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (_) async {
          emit(const CustomerActionSuccess('register.saved'));
          await _reload(emit);
        },
      );
    }
  }

  Future<void> _onDeleteRequested(
      CustomerDeleteRequested event, Emitter<CustomerBlocState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(CustomerActionFailure(failure.message)),
      (_) async {
        emit(const CustomerActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
