import 'entity/service_entity.dart';

/// Regras LOCAIS da aba IBS/CBS do cadastro de Serviços (fase IBS/CBS,
/// D-IB6) — espelho do que a API aceita (serviceDto + peça
/// @shared/ibscbs-classification). A API continua sendo a autoridade:
/// vigência, aceitação na NFS-e e existência no catálogo são dela (422
/// IBSCBS_* com fields[]). Aqui fica só o que dá para saber sem perguntar:
/// os DOIS códigos da classificação vão JUNTOS.
///
/// As funções devolvem CHAVE i18n (a mecânica de pendência aplica .tr()) ou
/// null quando o campo está ok.

/// Pendência da Classificação Tributária (cClassTrib): o Indicador da
/// Operação foi escolhido e a classificação ficou vazia.
const ibscbsClassificationRequiredKey =
    'forms.services.ibscbsClassificationRequired';

/// Pendência do Indicador da Operação (cIndOp): a classificação foi
/// escolhida e o indicador ficou vazio.
const ibscbsPlaceIndicatorRequiredKey =
    'forms.services.ibscbsPlaceIndicatorRequired';

bool _blank(String? code) => code == null || code.trim().isEmpty;

/// Classificação vazia com o indicador preenchido → pendência.
String? ibscbsClassificationPendency(
        String? classificationCode, String? placeIndicatorCode) =>
    _blank(classificationCode) && !_blank(placeIndicatorCode)
        ? ibscbsClassificationRequiredKey
        : null;

/// Indicador vazio com a classificação preenchida → pendência.
String? ibscbsPlaceIndicatorPendency(
        String? classificationCode, String? placeIndicatorCode) =>
    !_blank(classificationCode) && _blank(placeIndicatorCode)
        ? ibscbsPlaceIndicatorRequiredKey
        : null;

/// Payload da classificação: os dois códigos → par; nenhum → null (a API
/// remove a classificação). Par INCOMPLETO também vira null — quem chama
/// barra antes pelas pendências acima (nunca manda meio par).
ServiceIbscbsInput? ibscbsInputOf(
        String? classificationCode, String? placeIndicatorCode) =>
    _blank(classificationCode) || _blank(placeIndicatorCode)
        ? null
        : ServiceIbscbsInput(
            classificationCode: classificationCode!.trim(),
            placeIndicatorCode: placeIndicatorCode!.trim(),
          );

/// NBS do payload: vazio → null (a API remove a NBS).
String? nbsInputOf(String? nbs) => _blank(nbs) ? null : nbs!.trim();

/// Texto do avatar na lista de apoio da NBS: capítulo no formato oficial
/// ("101011100" → "1.01"); a linha traz o código inteiro.
String nbsAvatar(String code) =>
    code.length >= 3 ? '${code[0]}.${code.substring(1, 3)}' : code;

/// Texto do avatar na lista de apoio do cIndOp: o GRUPO do Anexo VII
/// (2 primeiros dígitos — "01" bem móvel, "10" demais...).
String placeIndicatorAvatar(String code) =>
    code.length >= 2 ? code.substring(0, 2) : code;

/// Chave i18n "vale a partir de" (com fim: "vale de … até …").
const ibscbsValidFromKey = 'forms.services.ibscbsValidFrom';
const ibscbsValidRangeKey = 'forms.services.ibscbsValidRange';

/// "AAAA-MM-DD" → "DD/MM/AAAA"; vazio/fora do formato → null.
String? ibscbsBrDate(String? iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso ?? '');
  return m == null ? null : '${m[3]}/${m[2]}/${m[1]}';
}

/// Vigência da classificação escolhida para exibir sob o campo (D-IB29):
/// chave i18n + argumentos (datas já em DD/MM/AAAA); sem início → null.
({String key, List<String> args})? ibscbsValidity(
    String? validFrom, String? validUntil) {
  final from = ibscbsBrDate(validFrom);
  if (from == null) return null;
  final until = ibscbsBrDate(validUntil);
  return until == null
      ? (key: ibscbsValidFromKey, args: [from])
      : (key: ibscbsValidRangeKey, args: [from, until]);
}

/// Linha da lista de apoio do cClassTrib (D-IB29): a classificação que só
/// começa a valer depois de [today] leva "(vale a partir de …)" — o texto é da
/// TELA (i18n); a API manda só a data.
({String key, List<String> args})? ibscbsFutureValidity(
    String? validFrom, DateTime today) {
  final from = ibscbsBrDate(validFrom);
  if (from == null) return null;
  final iso = '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}';
  return validFrom!.compareTo(iso) > 0
      ? (key: ibscbsValidFromKey, args: [from])
      : null;
}
