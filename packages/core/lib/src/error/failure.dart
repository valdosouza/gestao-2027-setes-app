import 'package:equatable/equatable.dart';

/// Erro por campo do envelope `{ error, fields: [{ field, message }] }`
/// (Fase 2, decisão de validação; Fase 3 usa `field: 'id'` no 409 de papel
/// duplicado — o `message` carrega o id do registro existente).
class FailureField extends Equatable {
  const FailureField({required this.field, required this.message});

  final String field;
  final String message;

  factory FailureField.fromJson(Map<String, dynamic> json) => FailureField(
        field:   json['field'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );

  @override
  List<Object?> get props => [field, message];
}

/// Falha de domínio (decisão 12: operações assíncronas retornam
/// `Either<Failure, T>` via dartz).
class Failure extends Equatable {
  const Failure({required this.message, this.statusCode, this.fields = const []});

  final String message;
  final int? statusCode;

  /// Campos que causaram o erro (vazio quando a API não detalhou).
  final List<FailureField> fields;

  /// Mensagem do campo [field] (null se a API não apontou este campo).
  String? fieldMessage(String field) {
    for (final f in fields) {
      if (f.field == field) return f.message;
    }
    return null;
  }

  @override
  List<Object?> get props => [message, statusCode, fields];

  /// A mensagem É a representação textual — consumidores genéricos (ex.:
  /// o dialog de lookup) exibem o erro sem conhecer o tipo Failure.
  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Falha de conexão com o servidor'});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Sessão inválida ou expirada'})
      : super(statusCode: 401);
}
