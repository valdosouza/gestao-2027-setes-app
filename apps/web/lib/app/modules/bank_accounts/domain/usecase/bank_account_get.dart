import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_account_entity.dart';
import '../repository/bank_account_repository.dart';

/// Carrega a conta COMPLETA (GET /:id) para edição — a lista não traz
/// datas nem telefone.
class BankAccountGet {
  const BankAccountGet({required this.repository});

  final BankAccountRepository repository;

  Future<Either<Failure, BankAccountFull>> call(int id) =>
      repository.getById(id);
}
