import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';

/// Contrato do repositório de Cheques (Either/dartz) — operações do
/// PROCESSO: lista por estado derivado, detalhe e as 7 ações que portam o
/// cheque de um estado a outro. Lookups (bancos/contas/fornecedores/
/// títulos a pagar) NÃO passam pelo repositório — a página fala direto com
/// o [CheckLookupDatasource] dedicado (regra da tela-de-processo).
abstract class CheckRepository {
  Future<Either<Failure, PagedResult<CheckListRow>>> getList(
      String status, String filter,
      {int page = 1, int? pageSize});
  Future<Either<Failure, CheckFull>> getOne(int id);

  /// Deposita (evento B) — cofre → banco.
  Future<Either<Failure, CheckSettledResult>> deposit(
      int id, String dtRecord, int bankAccountId);

  /// Desconta na factoring (evento D).
  Future<Either<Failure, CheckSettledResult>> discount(int id, String dtRecord,
      int factoringEntityId, int bankAccountId, double feeValue);

  /// Retorno com reembolso (evento T) — sem fundos na factoring.
  Future<Either<Failure, CheckSettledResult>> returnRefund(
      int id, String dtRecord, int bankAccountId);

  /// Retorno bom (evento F) — pré-datado compensou, sem movimento.
  Future<Either<Failure, int>> returnGood(int id, String? note);

  /// Usa em pagamento (evento P) — quita um título a pagar.
  Future<Either<Failure, CheckSettledResult>> pay(
      int id, String dtRecord, int orderId, int parcel);

  /// Devolve (evento V) — sem fundos; cria título novo contra a origem.
  Future<Either<Failure, CheckReturnResult>> returnToOrigin(
      int id, String dtRecord, String? note);

  /// Estorna o último evento (evento X).
  Future<Either<Failure, CheckReverseResult>> reverse(
      int id, int event, String reason);
}
