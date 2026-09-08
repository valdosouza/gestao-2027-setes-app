import 'package:equatable/equatable.dart';

/// Erro por campo do envelope `{ error, fields: [{ field, message,
/// expected? }] }` (Fase 2, decisão de validação; Fase 3 usa `field: 'id'`
/// no 409 de papel duplicado — o `message` carrega o id do registro
/// existente). [expected] = valor ESPERADO nos erros de conferência
/// numérica (D-N3 da negociação do pedido, 2026-09-07: INSTALLMENT_MISMATCH
/// traz a base do pedido, MAX_PARCELS_EXCEEDED o limite, CHECK_SUM_MISMATCH
/// o valor da parcela) — a tela corrige com o número, nunca com parse da
/// prosa da mensagem. Ausente na maioria dos erros.
class FailureField extends Equatable {
  const FailureField({
    required this.field,
    required this.message,
    this.expected,
  });

  final String field;
  final String message;
  final double? expected;

  factory FailureField.fromJson(Map<String, dynamic> json) => FailureField(
        field:    json['field'] as String? ?? '',
        message:  json['message'] as String? ?? '',
        expected: (json['expected'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [field, message, expected];
}

/// Falha de domínio (decisão 12: operações assíncronas retornam
/// `Either<Failure, T>` via dartz).
///
/// Framework de Mensagens (prompt_framework_mensagens_validacao.md):
/// [message] pode ser CHAVE i18n `core.errors.*` (defaults locais) — a ponte
/// de feedback do app traduz com .tr(); chave inexistente retorna a própria
/// string, então mensagens PT do backend passam intactas. A natureza do erro
/// deriva do status/[supportRef] (R7) — nunca de um campo de severidade.
class Failure extends Equatable {
  const Failure({
    required this.message,
    this.statusCode,
    this.fields = const [],
    this.code,
    this.supportRef,
  });

  final String message;
  final int? statusCode;

  /// Campos que causaram o erro (vazio quando a API não detalhou).
  final List<FailureField> fields;

  /// Código do catálogo de erros conhecidos (`code` do envelope — R8).
  final String? code;

  /// Código curto de rastro do erro técnico (`ref` do envelope — linha na
  /// tb_crashlytics central): o usuário informa ao suporte (R2).
  final String? supportRef;

  /// Mensagem do campo [field] (null se a API não apontou este campo).
  String? fieldMessage(String field) {
    for (final f in fields) {
      if (f.field == field) return f.message;
    }
    return null;
  }

  /// Valor esperado apontado no campo [field] (null quando a API não o
  /// informou — só os erros de conferência numérica carregam `expected`).
  double? fieldExpected(String field) {
    for (final f in fields) {
      if (f.field == field) return f.expected;
    }
    return null;
  }

  @override
  List<Object?> get props => [message, statusCode, fields, code, supportRef];

  /// A mensagem É a representação textual — consumidores genéricos (ex.:
  /// o dialog de lookup) exibem o erro sem conhecer o tipo Failure.
  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  /// [detail] é a exceção técnica original (ex.: `ClientException: Failed to
  /// fetch, uri=...`) — reaproveita a linha de código de suporte (R2) para
  /// expor a causa real em vez do "falha de conexão" genérico sem pista.
  const NetworkFailure({super.message = 'core.errors.network', String? detail})
      : super(supportRef: detail);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'core.errors.session',
    super.code,
    super.supportRef,
  }) : super(statusCode: 401);
}
