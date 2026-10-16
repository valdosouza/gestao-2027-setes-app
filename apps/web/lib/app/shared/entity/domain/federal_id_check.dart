import 'package:setes_validators/setes_validators.dart';

/// D-CJ8 (onda 1 da frente do CNPJ alfanumérico): o julgamento ÚNICO do CPF/CNPJ do formulário de entidade — a marca inline do campo
/// (`EntityMainTab`) e a pendência das 5 páginas (institution, cliente, fornecedor, transportadora, colaborador) chamam ESTAS funções: a
/// marca nunca mente para a pendência (R3) por construção. A regra é a da peça (`FederalIdRules`: forma canônica + DV ASCII − 48); o texto
/// digitado é canonicalizado pela peça (máscara sai, minúscula sobe, nada é apagado) antes de julgar — EXATAMENTE como a API: gate
/// adversarial da onda 1 (LOW) — com o `String.trim()` do Dart aqui, um NEL (U+0085) nas pontas dava OK no app e 400 na API.
enum FederalIdProblem { missing, invalid }

FederalIdProblem? cpfProblem(String? text) => _problem(text, FederalIdRules.isValidCpf);

FederalIdProblem? cnpjProblem(String? text) => _problem(text, FederalIdRules.isValidCnpj);

FederalIdProblem? _problem(String? text, bool Function(String?) isValid) {
  if (text == null) return FederalIdProblem.missing;
  final canonical = FederalIdRules.canonicalizeText(text);
  if (canonical == null) return FederalIdProblem.invalid;        // caractere estranho (inclusive nas pontas): a API recusa igual
  if (canonical.isEmpty) return FederalIdProblem.missing;        // só brancos/literais
  return isValid(canonical) ? null : FederalIdProblem.invalid;
}
