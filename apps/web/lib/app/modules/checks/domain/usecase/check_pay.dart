import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/check_entity.dart';
import '../repository/check_repository.dart';

/// Usa o cheque em pagamento (evento P) — quita um título a pagar aberto
/// com o valor de face. Só em custódia.
class CheckPay {
  const CheckPay({required this.repository});

  final CheckRepository repository;

  Future<Either<Failure, CheckSettledResult>> call(
          int id, String dtRecord, int orderId, int parcel) =>
      repository.pay(id, dtRecord, orderId, parcel);
}
