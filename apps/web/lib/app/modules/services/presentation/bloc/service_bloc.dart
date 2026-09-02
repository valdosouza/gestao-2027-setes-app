import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_entity.dart';
import '../../domain/usecase/service_delete.dart';
import '../../domain/usecase/service_get.dart';
import '../../domain/usecase/service_getlist.dart';
import '../../domain/usecase/service_post.dart';
import '../../domain/usecase/service_price_lists_get.dart';
import '../../domain/usecase/service_put.dart';

part 'service_event.dart';
part 'service_state.dart';

/// Orquestra o Cadastro de Serviços (prompt_modulo_services.md): lista ↔
/// formulário. A edição carrega o serviço COMPLETO (GET /:id, com a grade
/// de preços); o serviço novo carrega as tabelas de preço vivas para a
/// grade nascer com todas as linhas (D4/D7). Filtro REMOTO + paginação no
/// molde bank_accounts.
class ServiceBloc extends Bloc<ServiceEvent, ServiceState> {
  ServiceBloc({
    required this.getlist,
    required this.get,
    required this.getPriceLists,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const ServiceListState(loading: true)) {
    on<ServiceListRequested>(_onListRequested);
    on<ServiceNewPressed>(_onNewPressed);
    on<ServiceEditPressed>(_onEditPressed);
    on<ServiceBackToListPressed>((event, emit) => _reload(emit));
    on<ServiceSaveRequested>(_onSaveRequested);
    on<ServiceDeleteRequested>(_onDeleteRequested);
  }

  final ServiceGetlist getlist;
  final ServiceGet get;
  final ServicePriceListsGet getPriceLists;
  final ServicePost post;
  final ServicePut put;
  final ServiceDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Serviço aberto no form (null = novo) + grade inicial — preservados nos
  /// re-emits de saving/falha (o form continua montado).
  ServiceFull? _editing;
  List<ServicePrice> _prices = const [];

  Future<void> _onListRequested(
      ServiceListRequested event, Emitter<ServiceState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ServiceState> emit) async {
    emit(const ServiceListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(ServiceActionFailure(failure));
        emit(const ServiceListState());
      },
      (paged) async {
        // Página esvaziou (ex.: exclusão do último item) → recua para a
        // última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(ServiceListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<ServiceListItem> get _currentItems {
    final current = state;
    return current is ServiceListState ? current.items : const [];
  }

  /// Novo: a grade da aba Preços precisa das tabelas vivas ANTES do form
  /// abrir. Falha na consulta não bloqueia o cadastro — o form abre com a
  /// grade vazia e a falha vai para a ponte.
  Future<void> _onNewPressed(
      ServiceNewPressed event, Emitter<ServiceState> emit) async {
    emit(ServiceListState(items: _currentItems, loading: true));
    final result = await getPriceLists();
    _editing = null;
    _prices = result.fold((_) => const [], (lists) => lists);
    result.fold(
      (failure) => emit(ServiceActionFailure(failure)),
      (_) {},
    );
    emit(ServiceFormState(prices: _prices));
  }

  Future<void> _onEditPressed(
      ServiceEditPressed event, Emitter<ServiceState> emit) async {
    emit(ServiceListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(ServiceActionFailure(failure));
        emit(ServiceListState(items: _currentItems));
      },
      (full) async {
        _editing = full;
        _prices = full.prices;
        emit(ServiceFormState(editing: full, prices: _prices));
      },
    );
  }

  Future<void> _onSaveRequested(
      ServiceSaveRequested event, Emitter<ServiceState> emit) async {
    emit(ServiceFormState(editing: _editing, prices: _prices, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(ServiceActionFailure(failure));
        // Mesmo editing/grade → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(ServiceFormState(editing: _editing, prices: _prices));
      },
      (_) async {
        emit(const ServiceActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      ServiceDeleteRequested event, Emitter<ServiceState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(ServiceActionFailure(failure)),
      (_) async {
        emit(const ServiceActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
