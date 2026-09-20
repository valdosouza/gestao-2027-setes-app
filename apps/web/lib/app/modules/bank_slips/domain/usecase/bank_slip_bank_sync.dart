import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/bank_slip_entity.dart';
import '../repository/bank_slip_repository.dart';

/// Consulta ativa THROTTLED das apresentações vivas (Onda 2 — D-I9, gatilho
/// da onda sem URL pública): POST /api/bank-slips/refresh. A tela chama ao
/// abrir e no botão "Atualizar com o banco"; a API só reconsulta o que não foi
/// visto há N minutos (rate limit do sandbox).
class BankSlipBankSync {
  const BankSlipBankSync({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, BankSlipBankSyncReport>> call() => repository.bankSync();
}
