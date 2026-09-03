import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_tax_rule_entity.dart';
import '../../domain/usecase/service_tax_rule_delete.dart';
import '../../domain/usecase/service_tax_rule_get.dart';
import '../../domain/usecase/service_tax_rule_getlist.dart';
import '../../domain/usecase/service_tax_rule_post.dart';
import '../../domain/usecase/service_tax_rule_put.dart';

part 'service_tax_rule_event.dart';
part 'service_tax_rule_state.dart';

/// Orquestra as Regras de Tributação de Serviço: lista ↔ formulário. A
/// edição recarrega a regra (GET /:id); o filtro da tela é REMOTO
/// (?filter= — molde bank_accounts).
class ServiceTaxRuleBloc
    extends Bloc<ServiceTaxRuleEvent, ServiceTaxRuleState> {
  ServiceTaxRuleBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const ServiceTaxRuleListState(loading: true)) {
    on<ServiceTaxRuleListRequested>(_onListRequested);
    on<ServiceTaxRuleNewPressed>((event, emit) {
      _editing = null;
      emit(const ServiceTaxRuleFormState());
    });
    on<ServiceTaxRuleEditPressed>(_onEditPressed);
    on<ServiceTaxRuleBackToListPressed>((event, emit) => _reload(emit));
    on<ServiceTaxRuleSaveRequested>(_onSaveRequested);
    on<ServiceTaxRuleDeleteRequested>(_onDeleteRequested);
  }

  final ServiceTaxRuleGetlist getlist;
  final ServiceTaxRuleGet get;
  final ServiceTaxRulePost post;
  final ServiceTaxRulePut put;
  final ServiceTaxRuleDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Regra aberta no form (null = nova) — preserva o editing nos re-emits
  /// de saving/falha.
  ServiceTaxRuleEntity? _editing;

  Future<void> _onListRequested(ServiceTaxRuleListRequested event,
      Emitter<ServiceTaxRuleState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ServiceTaxRuleState> emit) async {
    emit(const ServiceTaxRuleListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(ServiceTaxRuleActionFailure(failure));
        emit(const ServiceTaxRuleListState());
      },
      (paged) async {
        // Página esvaziou (ex.: exclusão do último item) → recua para a
        // última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API).
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(ServiceTaxRuleListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<ServiceTaxRuleEntity> get _currentItems {
    final current = state;
    return current is ServiceTaxRuleListState ? current.items : const [];
  }

  Future<void> _onEditPressed(ServiceTaxRuleEditPressed event,
      Emitter<ServiceTaxRuleState> emit) async {
    emit(ServiceTaxRuleListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(ServiceTaxRuleActionFailure(failure));
        emit(ServiceTaxRuleListState(items: _currentItems));
      },
      (rule) async {
        _editing = rule;
        emit(ServiceTaxRuleFormState(editing: rule));
      },
    );
  }

  Future<void> _onSaveRequested(ServiceTaxRuleSaveRequested event,
      Emitter<ServiceTaxRuleState> emit) async {
    emit(ServiceTaxRuleFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(ServiceTaxRuleActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(ServiceTaxRuleFormState(editing: _editing));
      },
      (_) async {
        emit(const ServiceTaxRuleActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(ServiceTaxRuleDeleteRequested event,
      Emitter<ServiceTaxRuleState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      // 409 SERVICE_TAX_RULE_IN_USE chega aqui — a ponte mostra a mensagem
      // e o form permanece aberto.
      (failure) async => emit(ServiceTaxRuleActionFailure(failure)),
      (_) async {
        emit(const ServiceTaxRuleActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
