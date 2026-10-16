import 'package:setes_validators/setes_validators.dart';

/// D-CJ8 (onda 1 da frente do CNPJ alfanumérico): o julgamento ÚNICO do CPF/CNPJ do formulário de entidade — a marca inline do campo
/// (`EntityMainTab`) e a pendência das 5 páginas (institution, cliente, fornecedor, transportadora, colaborador) chamam ESTAS funções: a
/// marca nunca mente para a pendência (R3) por construção. A regra é a da peça (`FederalIdRules`: forma canônica + DV ASCII − 48); o texto
/// digitado é canonicalizado (máscara sai, minúscula sobe, nada é apagado) antes de julgar — como a API faz.
enum FederalIdProblem { missing, invalid }

FederalIdProblem? cpfProblem(String? text) => _problem(text, FederalIdRules.isValidCpf);

FederalIdProblem? cnpjProblem(String? text) => _problem(text, FederalIdRules.isValidCnpj);

FederalIdProblem? _problem(String? text, bool Function(String?) isValid) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return FederalIdProblem.missing;
  return isValid(FederalIdRules.canonicalizeText(t)) ? null : FederalIdProblem.invalid;
}
