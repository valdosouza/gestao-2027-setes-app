import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/bank_slip_repository.dart';

/// PDF OFICIAL do banco (GET /api/bank-slips/:id/pdf) — base64 no envelope;
/// a tela abre em nova aba.
class BankSlipPdf {
  const BankSlipPdf({required this.repository});

  final BankSlipRepository repository;

  Future<Either<Failure, String>> call(int id) => repository.pdf(id);
}
