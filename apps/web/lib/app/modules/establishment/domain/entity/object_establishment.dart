import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/entity/domain/object_entity.dart';

/// tb_institution do PRÓPRIO estabelecimento do usuário logado — módulo
/// `establishment` (menu "Meu Estabelecimento"). Cardinalidade 1 garantida
/// pela API via token (institutionId implícito): NUNCA existe `:id` na URL
/// e a tela NUNCA passa por lista (parecer setes-conceito, 2026-08-25).
///
/// Reaproveita as MESMAS listas de apoio da cadeia de entidade fiscal
/// (EntityAddress/EntityPhone/EntitySocialMedia de shared/entity) — só o
/// subconjunto de campos é restrito (decisão fechada com o usuário):
/// document/personType são SOMENTE EXIBIÇÃO (nunca viajam no PUT).
///
/// Onda 3 (NFS-e pelo ADN — prompt_onda_nfe_sefaz.md §9.3, fatos do
/// EMITENTE): [simplesRegime] (opSimpNac), [specialTaxRegime] (regEspTrib)
/// e [cnae] viajam no PUT ao lado do [taxRegime] — null = limpa.
class ObjectEstablishment extends Equatable {
  const ObjectEstablishment({
    this.nameCompany = '',
    this.nickTrade = '',
    this.document = '',
    this.personType = 'J',
    this.ie,
    this.im,
    this.taxRegime,
    this.simplesRegime,
    this.simplesAssessment,
    this.simplesTotalTaxAliquot,
    this.specialTaxRegime,
    this.cnae,
    this.addresses = const [],
    this.phones = const [],
    this.socialMedia = const [],
  });

  /// Valores canônicos da API para [simplesRegime] (opSimpNac do DPS):
  /// 1 não optante · 2 MEI · 3 ME/EPP (Simples Nacional). Rótulos = i18n
  /// `forms.establishment.simplesRegime<N>`.
  static const simplesRegimes = ['1', '2', '3'];

  /// Valores canônicos da API para [simplesAssessment] (regApTribSN do DPS —
  /// D-N19a, só para ME/EPP que ultrapassou sublimite): 1 tudo pelo SN ·
  /// 2 ISSQN por fora · 3 tudo por fora. Rótulos = i18n
  /// `forms.establishment.simplesAssessment<N>`.
  static const simplesAssessments = ['1', '2', '3'];

  /// Valores canônicos da API para [specialTaxRegime] (regEspTrib do DPS):
  /// 0 nenhum · 1 ato cooperado · 2 estimativa · 3 microempresa municipal ·
  /// 4 notário/registrador · 5 profissional autônomo · 6 sociedade de
  /// profissionais. Rótulos = i18n `forms.establishment.specialTaxRegime<N>`.
  static const specialTaxRegimes = ['0', '1', '2', '3', '4', '5', '6'];

  final String nameCompany;
  final String nickTrade;

  /// CPF/CNPJ — SOMENTE EXIBIÇÃO (desabilitado na tela, nunca enviado).
  final String document;

  /// 'F' | 'J' — SOMENTE EXIBIÇÃO.
  final String personType;

  final String? ie;
  final String? im;

  /// Regime tributário do estabelecimento (D39 — campo avulso, mantido SÓ
  /// aqui): rótulo canônico da API (TAX_REGIMES) — não se traduz.
  final String? taxRegime;

  /// Situação perante o Simples Nacional ('1' | '2' | '3' | null).
  final String? simplesRegime;

  /// Regime de apuração no Simples ('1'..'3'). Só existe com [simplesRegime]
  /// == '3', e aí é OBRIGATÓRIO (Q-N36 — o fisco recusa a ausência, E0166).
  final String? simplesAssessment;

  /// % aproximado da alíquota efetiva do Simples (DAS) — pTotTribSN do DPS.
  /// TEXTO como digitado (vírgula ou ponto); o PUT converte. Só com
  /// [simplesRegime] == '3', e aí OBRIGATÓRIO (Q-N37 — E0712 do fisco).
  final String? simplesTotalTaxAliquot;

  /// Converte o texto do % (vírgula ou ponto) — null se vazio/inválido.
  static double? parseAliquot(String? text) {
    final t = (text ?? '').trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// Regime especial de tributação ('0'..'6' | null).
  final String? specialTaxRegime;

  /// CNAE principal — 7 dígitos, opcional.
  final String? cnae;

  final List<EntityAddress> addresses;
  final List<EntityPhone> phones;
  final List<EntitySocialMedia> socialMedia;

  factory ObjectEstablishment.fromJson(Map<String, dynamic> json) =>
      ObjectEstablishment(
        nameCompany: json['nameCompany'] as String? ?? '',
        nickTrade:   json['nickTrade'] as String? ?? '',
        document:    json['document'] as String? ?? '',
        personType:  json['personType'] as String? ?? 'J',
        ie:          json['ie'] as String?,
        im:          json['im'] as String?,
        taxRegime:   json['taxRegime'] as String?,
        // Códigos de 1 dígito: a API pode devolver int ou string — normaliza.
        simplesRegime:    _codeOrNull(json['simplesRegime']),
        simplesAssessment: _codeOrNull(json['simplesAssessment']),
        simplesTotalTaxAliquot: json['simplesTotalTaxAliquot'] == null
            ? null
            : jsonDouble(json['simplesTotalTaxAliquot'])
                ?.toStringAsFixed(2)
                .replaceAll('.', ','),
        specialTaxRegime: _codeOrNull(json['specialTaxRegime']),
        cnae:             _codeOrNull(json['cnae']),
        addresses: ObjectEntity.listFromJson(
            json['addresses'], EntityAddress.fromJson),
        phones: ObjectEntity.listFromJson(json['phones'], EntityPhone.fromJson),
        // Contrato da API usa "socials" (EstablishmentDto.socials).
        socialMedia: ObjectEntity.listFromJson(
            json['socials'], EntitySocialMedia.fromJson),
      );

  static String? _codeOrNull(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  /// Texto vazio vira null no PUT (o usuário limpou o campo).
  static String? _nullIfEmpty(String? v) {
    final s = v?.trim() ?? '';
    return s.isEmpty ? null : s;
  }

  /// Body do PUT (EstablishmentUpdateDto) — SEM document/personType.
  Map<String, dynamic> toJson() => {
        'nameCompany': nameCompany.trim(),
        'nickTrade':   nickTrade.trim(),
        if (ie != null && ie!.trim().isNotEmpty) 'ie': ie!.trim(),
        if (im != null && im!.trim().isNotEmpty) 'im': im!.trim(),
        // Sempre viajam (null = limpa): o draft nasce do GET, então
        // reenviar o valor corrente é idempotente.
        'taxRegime':        taxRegime,
        'simplesRegime':    _nullIfEmpty(simplesRegime),
        // D-N19a: a apuração e o % só existem para ME/EPP — fora dele viajam null (limpa)
        'simplesAssessment': _nullIfEmpty(simplesRegime) == '3'
            ? _nullIfEmpty(simplesAssessment) : null,
        'simplesTotalTaxAliquot': _nullIfEmpty(simplesRegime) == '3'
            ? parseAliquot(simplesTotalTaxAliquot) : null,
        'specialTaxRegime': _nullIfEmpty(specialTaxRegime),
        'cnae':             _nullIfEmpty(cnae),
        'addresses':   addresses.map((a) => a.toJson()).toList(),
        'phones':      phones.map((p) => p.toJson()).toList(),
        'socials':     socialMedia.map((s) => s.toJson()).toList(),
      };

  /// [simplesRegime]/[specialTaxRegime]/[cnae] aceitam '' para LIMPAR (o
  /// toJson converte em null) — `??` não distingue "não mexi" de "limpei".
  ObjectEstablishment copyWith({
    String? nameCompany,
    String? nickTrade,
    String? ie,
    String? im,
    String? taxRegime,
    String? simplesRegime,
    String? simplesAssessment,
    String? simplesTotalTaxAliquot,
    String? specialTaxRegime,
    String? cnae,
    List<EntityAddress>? addresses,
    List<EntityPhone>? phones,
    List<EntitySocialMedia>? socialMedia,
  }) =>
      ObjectEstablishment(
        nameCompany: nameCompany ?? this.nameCompany,
        nickTrade:   nickTrade ?? this.nickTrade,
        document:    document,
        personType:  personType,
        ie:          ie ?? this.ie,
        im:          im ?? this.im,
        taxRegime:   taxRegime ?? this.taxRegime,
        simplesRegime:    simplesRegime ?? this.simplesRegime,
        simplesAssessment: simplesAssessment ?? this.simplesAssessment,
        simplesTotalTaxAliquot:
            simplesTotalTaxAliquot ?? this.simplesTotalTaxAliquot,
        specialTaxRegime: specialTaxRegime ?? this.specialTaxRegime,
        cnae:             cnae ?? this.cnae,
        addresses:   addresses ?? this.addresses,
        phones:      phones ?? this.phones,
        socialMedia: socialMedia ?? this.socialMedia,
      );

  @override
  List<Object?> get props => [
        nameCompany, nickTrade, document, personType, ie, im, taxRegime,
        simplesRegime, simplesAssessment, simplesTotalTaxAliquot,
        specialTaxRegime, cnae,
        addresses, phones, socialMedia,
      ];
}
