import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/bank_charge_agreement_entity.dart';
import '../../domain/usecase/bank_charge_agreement_delete.dart';
import '../../domain/usecase/bank_charge_agreement_get.dart';
import '../../domain/usecase/bank_charge_agreement_getlist.dart';
import '../../domain/usecase/bank_charge_agreement_post.dart';
import '../../domain/usecase/bank_charge_agreement_put.dart';

import '../../../../shared/search/search_criterion.dart';

part 'bank_charge_agreement_event.dart';
part 'bank_charge_agreement_state.dart';

/// Orquestra as Carteiras de Cobrança: lista ↔ formulário. A edição carrega
/// a carteira COMPLETA (GET /:id) porque a lista não traz encargos/
/// instrução/protesto; o filtro da tela é REMOTO (?filter= — molde
/// bank_accounts/settlement_rules).
class BankChargeAgreementBloc
    extends Bloc<BankChargeAgreementEvent, BankChargeAgreementState> {
  BankChargeAgreementBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const BankChargeAgreementListState(loading: true)) {
    on<BankChargeAgreementListRequested>(_onListRequested);
    on<BankChargeAgreementNewPressed>((event, emit) {
      _editing = null;
      emit(const BankChargeAgreementFormState());
    });
    on<BankChargeAgreementEditPressed>(_onEditPressed);
    on<BankChargeAgreementBackToListPressed>((event, emit) => _reload(emit));
    on<BankChargeAgreementSaveRequested>(_onSaveRequested);
    on<BankChargeAgreementDeleteRequested>(_onDeleteRequested);
  }

  final BankChargeAgreementGetlist getlist;
  final BankChargeAgreementGet get;
  final BankChargeAgreementPost post;
  final BankChargeAgreementPut put;
  final BankChargeAgreementDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  /// Carteira aberta no form (null = nova) — preserva o editing nos
  /// re-emits de saving/falha.
  BankChargeAgreementFull? _editing;

  Future<void> _onListRequested(BankChargeAgreementListRequested event,
      Emitter<BankChargeAgreementState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<BankChargeAgreementState> emit) async {
    emit(BankChargeAgreementListState(
        loading: true, filter: _filter, criteria: _criteria));
    final result = await getlist(_filter,
        page: _page, pageSize: _pageSize, criteria: _criteria);
    await result.fold(
      (failure) async {
        // Q-BA16 (a): critério recusado pela API é DESCARTADO, o usuário é
        // avisado e a lista recarrega com os demais — nunca fica travada.
        final pruned = _criteria.withoutRejected(failure);
        if (pruned != null) {
          _criteria = pruned;
          emit(BankChargeAgreementActionFailure(
              searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(BankChargeAgreementActionFailure(failure));
        emit(BankChargeAgreementListState(
            filter: _filter, criteria: _criteria));
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
        emit(BankChargeAgreementListState(
          items: paged.items,
          filter: _filter,
          criteria: _criteria,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<BankChargeAgreementListItem> get _currentItems {
    final current = state;
    return current is BankChargeAgreementListState
        ? current.items
        : const [];
  }

  Future<void> _onEditPressed(BankChargeAgreementEditPressed event,
      Emitter<BankChargeAgreementState> emit) async {
    emit(BankChargeAgreementListState(
        items: _currentItems, loading: true, criteria: _criteria));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(BankChargeAgreementActionFailure(failure));
        emit(BankChargeAgreementListState(
            items: _currentItems, criteria: _criteria));
      },
      (full) async {
        _editing = full;
        emit(BankChargeAgreementFormState(editing: full));
      },
    );
  }

  Future<void> _onSaveRequested(BankChargeAgreementSaveRequested event,
      Emitter<BankChargeAgreementState> emit) async {
    emit(BankChargeAgreementFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(BankChargeAgreementActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(BankChargeAgreementFormState(editing: _editing));
      },
      (_) async {
        emit(const BankChargeAgreementActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(BankChargeAgreementDeleteRequested event,
      Emitter<BankChargeAgreementState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(BankChargeAgreementActionFailure(failure)),
      (_) async {
        emit(const BankChargeAgreementActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
