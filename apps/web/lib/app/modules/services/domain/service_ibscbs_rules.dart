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
