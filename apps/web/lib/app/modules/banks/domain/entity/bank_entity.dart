import 'package:equatable/equatable.dart';

/// Banco (setes_central.tb_bank) — interface 'banks' do módulo Super
/// (decisão do Valdo 2026-08-04, fecho da decisão 8 da Fase 3: catálogo
/// FEBRABAN central, SEM cadeia fiscal). Acesso exclusivamente via
/// setes-api /api/banks; o consumo pelos clientes segue no lookup
/// /api/bank-accounts/banks (módulo bank_accounts, intocado).
class BankEntity extends Equatable {
  const BankEntity({required this.id, this.number, this.description});

  /// Código INTERNO gerado pelo backend (MAX+1 — convenção do seed 17).
  /// 0 = ainda não gerado (inclusão).
  final int     id;

  /// Número FEBRABAN (3 dígitos), digitado pelo usuário e ÚNICO — 409 se
  /// em uso, mesmo por excluído. Editável na correção (não é a PK).
  final String? number;
  final String? description;

  factory BankEntity.fromJson(Map<String, dynamic> json) => BankEntity(
        id:          (json['id'] as num).toInt(),
        number:      json['number'] as String?,
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, number, description];
}
