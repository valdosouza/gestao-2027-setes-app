import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/entity/domain/object_entity.dart';
import '../../../../shared/entity/domain/object_entity_fiscal.dart';

/// Regimes tributários CANÔNICOS (Fase 3 Rodada 4, decisão 15) — o valor
/// gravado é o RÓTULO completo; o código NFe (CRT) é o 1º caractere
/// (Lucro Real e Presumido compartilham o 3). Espelho de TAX_REGIMES em
/// setes-api/src/shared/entity-tax/entity-tax.types.ts.
const List<String> kTaxRegimes = [
  '1 - Simples Nacional',
  '2 - Simples Nacional - excesso de sublimite de receita bruta',
  '3 - Regime Normal - Lucro Real',
  '3 - Regime Normal - Lucro Presumido',
];

/// Indicador de IE do destinatário (NFe) — códigos canônicos.
const List<String> kIndIeDestCodes = ['1', '2', '9'];

/// Exigibilidade do ISS — códigos CHAR(2) do legado (decisão 15).
const List<String> kIssExigibilidadeCodes = [
  '01', '02', '03', '04', '05', '06', '07',
];

/// Linha da PESQUISA de Clientes (GET /api/customers).
class CustomerListItem extends Equatable {
  const CustomerListItem({
    required this.id,
    this.nickTrade,
    this.nameCompany,
    this.active = false,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;
  final bool    active;

  factory CustomerListItem.fromJson(Map<String, dynamic> json) =>
      CustomerListItem(
        id:          (json['id'] as num).toInt(),
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
        active:      (json['active'] as String?) == 'S',
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany, active];
}

/// Resultado do POST (Fase 3, decisões 1 e 9): [reused] = a API reaproveitou
/// uma entity existente pelo CPF/CNPJ dentro da transação.
class CustomerPostResult extends Equatable {
  const CustomerPostResult({required this.id, required this.reused});

  final int  id;
  final bool reused;

  @override
  List<Object?> get props => [id, reused];
}

/// Fatia TRIBUTAÇÃO da relação comercial (tb_entity_tax — Fase 3 Rodada 4,
/// decisões 14–17): aba "Tributação" do form. Radioboxes S/N viram String
/// 'S'|'N'; checkboxes viram bool (serializados 'S'/'N' no toJson);
/// dropdowns gravam os valores canônicos ([kTaxRegimes], [kIndIeDestCodes],
/// [kIssExigibilidadeCodes]).
class EntityTaxData extends Equatable {
  const EntityTaxData({
    this.consumer = 'N',
    this.taxRegime,
    this.byPassSt = false,
    this.indIeDest,
    this.issExigibilidade,
    this.issProcessNr,
    this.issRetido = 'N',
    this.issIndIncFiscal = 'N',
    this.autoSendInvoice = false,
    this.autoSendInvoiceJustXml = false,
  });

  /// 'S' | 'N' (radiobox Consumidor Final).
  final String  consumer;

  /// Rótulo canônico completo de [kTaxRegimes] (ou null).
  final String? taxRegime;
  final bool    byPassSt;

  /// '1' | '2' | '9' (ou null).
  final String? indIeDest;

  /// '01'..'07' (ou null).
  final String? issExigibilidade;
  final String? issProcessNr;

  /// 'S' | 'N' (radiobox ISS Retido).
  final String  issRetido;

  /// 'S' | 'N' (radiobox Incentivo Fiscal ISS).
  final String  issIndIncFiscal;
  final bool    autoSendInvoice;
  final bool    autoSendInvoiceJustXml;

  factory EntityTaxData.fromJson(Map<String, dynamic> json) => EntityTaxData(
        consumer:         json['consumer'] as String? ?? 'N',
        taxRegime:        json['taxRegime'] as String?,
        byPassSt:         (json['byPassSt'] as String?) == 'S',
        indIeDest:        json['indIeDest'] as String?,
        issExigibilidade: json['issExigibilidade'] as String?,
        issProcessNr:     json['issProcessNr'] as String?,
        issRetido:        json['issRetido'] as String? ?? 'N',
        issIndIncFiscal:  json['issIndIncFiscal'] as String? ?? 'N',
        autoSendInvoice:  (json['autoSendInvoice'] as String?) == 'S',
        autoSendInvoiceJustXml:
            (json['autoSendInvoiceJustXml'] as String?) == 'S',
      );

  Map<String, dynamic> toJson() => {
        'consumer':               consumer,
        'taxRegime':              taxRegime,
        'byPassSt':               byPassSt ? 'S' : 'N',
        'indIeDest':              indIeDest,
        'issExigibilidade':       issExigibilidade,
        'issProcessNr':
            (issProcessNr == null || issProcessNr!.trim().isEmpty)
                ? null
                : issProcessNr!.trim(),
        'issRetido':              issRetido,
        'issIndIncFiscal':        issIndIncFiscal,
        'autoSendInvoice':        autoSendInvoice ? 'S' : 'N',
        'autoSendInvoiceJustXml': autoSendInvoiceJustXml ? 'S' : 'N',
      };

  /// Wrappers `Function()` nos anuláveis permitem LIMPAR (() => null).
  EntityTaxData copyWith({
    String? consumer,
    String? Function()? taxRegime,
    bool? byPassSt,
    String? Function()? indIeDest,
    String? Function()? issExigibilidade,
    String? Function()? issProcessNr,
    String? issRetido,
    String? issIndIncFiscal,
    bool? autoSendInvoice,
    bool? autoSendInvoiceJustXml,
  }) =>
      EntityTaxData(
        consumer:  consumer ?? this.consumer,
        taxRegime: taxRegime != null ? taxRegime() : this.taxRegime,
        byPassSt:  byPassSt ?? this.byPassSt,
        indIeDest: indIeDest != null ? indIeDest() : this.indIeDest,
        issExigibilidade: issExigibilidade != null
            ? issExigibilidade()
            : this.issExigibilidade,
        issProcessNr:
            issProcessNr != null ? issProcessNr() : this.issProcessNr,
        issRetido:       issRetido ?? this.issRetido,
        issIndIncFiscal: issIndIncFiscal ?? this.issIndIncFiscal,
        autoSendInvoice: autoSendInvoice ?? this.autoSendInvoice,
        autoSendInvoiceJustXml:
            autoSendInvoiceJustXml ?? this.autoSendInvoiceJustXml,
      );

  @override
  List<Object?> get props => [
        consumer, taxRegime, byPassSt, indIeDest, issExigibilidade,
        issProcessNr, issRetido, issIndIncFiscal, autoSendInvoice,
        autoSendInvoiceJustXml,
      ];
}

/// Concreta da cadeia de entidade fiscal (skill cadastro-entidade-fiscal.md):
/// ObjectEntity → ObjectEntityFiscal → ObjectCustomer (tb_customer no schema
/// do cliente — PK composta id + tb_institution_id; o escopo por institution
/// é da API via JWT).
///
/// Primeiro papel da Fase 3 Entidade Única: o app NUNCA envia entityId no
/// POST — a API resolve o reuso pelo documento dentro da transação
/// (decisão 9).
///
/// Rodada 4 (Tributação): consumer/byPassSt MIGRARAM para a fatia [tax]
/// (tb_entity_tax); [wallet] é a INTENÇÃO Sim/Não — a API resolve a forma
/// de pagamento "Carteira" sozinha (decisão 18, o app não lida com
/// tb_payment_types_id).
class ObjectCustomer extends ObjectEntityFiscal {
  const ObjectCustomer({
    this.id,
    this.tbSalesmanId,
    this.salesmanName,
    this.tbCarrierId,
    this.carrierName,
    this.creditStatus,
    this.creditValue,
    this.wallet = 'N',
    this.multiplier,
    this.active = true,
    this.tax,
    super.nameCompany,
    super.nickTrade,
    super.aniversary,
    super.addresses,
    super.phones,
    super.socialMedia,
    super.personType,
    super.person,
    super.company,
    super.noDoc,
  });

  /// null = inclusão (a API cria a cadeia OU reaproveita a entity pelo doc).
  final int? id;

  final int?    tbSalesmanId;
  final int?    tbCarrierId;

  /// 'L'(iberado) | 'B'(loqueado) | null (radiobox).
  final String? creditStatus;
  final double? creditValue;

  /// 'S' | 'N' — DERIVADO no GET (tb_payment_types_id > 0); no salvar é a
  /// intenção da UI (radiobox Sim/Não).
  final String  wallet;
  final double? multiplier;
  final bool    active;

  /// Aba Tributação (tb_entity_tax) — null no GET quando a relação ainda
  /// não tem tributação; o form SEMPRE envia (default no toJson).
  final EntityTaxData? tax;

  /// Nomes via JOIN da API — exibição dos lookups (campo-lookup-fk.md);
  /// nunca enviados.
  final String? salesmanName;
  final String? carrierName;

  factory ObjectCustomer.fromJson(Map<String, dynamic> json) {
    final entity = json['entity'] as Map<String, dynamic>? ?? const {};
    return ObjectCustomer(
      id:           (json['id'] as num?)?.toInt(),
      tbSalesmanId: jsonInt(json['tbSalesmanId']),
      salesmanName: json['salesmanName'] as String?,
      tbCarrierId:  jsonInt(json['tbCarrierId']),
      carrierName:  json['carrierName'] as String?,
      creditStatus: json['creditStatus'] as String?,
      creditValue:  jsonDouble(json['creditValue']),
      wallet:       json['wallet'] as String? ?? 'N',
      multiplier:   jsonDouble(json['multiplier']),
      active:       (json['active'] as String?) == 'S',
      tax: json['tax'] != null
          ? EntityTaxData.fromJson(json['tax'] as Map<String, dynamic>)
          : null,
      nameCompany:  entity['nameCompany'] as String? ?? '',
      nickTrade:    entity['nickTrade'] as String? ?? '',
      aniversary:   entity['aniversary'] as String?,
      personType:   json['personType'] as String? ?? 'J',
      person: json['person'] != null
          ? PersonData.fromJson(json['person'] as Map<String, dynamic>)
          : null,
      company: json['company'] != null
          ? CompanyData.fromJson(json['company'] as Map<String, dynamic>)
          : null,
      noDoc: json['noDoc'] != null
          ? NoDocData.fromJson(json['noDoc'] as Map<String, dynamic>)
          : null,
      addresses: ObjectEntity.listFromJson(
          json['addresses'], EntityAddress.fromJson),
      phones: ObjectEntity.listFromJson(json['phones'], EntityPhone.fromJson),
      socialMedia: ObjectEntity.listFromJson(
          json['socialMedia'], EntitySocialMedia.fromJson),
    );
  }

  /// Body do POST/PUT (customers.dto.ts). NUNCA envia id/entityId no POST
  /// (decisão 9) — o id da edição vai na URL. `tax` SEMPRE presente (a aba
  /// faz parte da tela — omitir significaria "não tocar" na API);
  /// multiplier vazio assume 1 (DEFAULT do banco).
  Map<String, dynamic> toJson() => {
        'entity': entityToJson(),
        ...fiscalToJson(),
        'addresses':   addresses.map((a) => a.toJson()).toList(),
        'phones':      phones.map((p) => p.toJson()).toList(),
        'socialMedia': socialMedia.map((s) => s.toJson()).toList(),
        'tbSalesmanId': tbSalesmanId,
        'tbCarrierId':  tbCarrierId,
        'creditStatus':
            (creditStatus == null || creditStatus!.trim().isEmpty)
                ? null
                : creditStatus!.trim(),
        'creditValue':  creditValue,
        'wallet':       wallet,
        'multiplier':   multiplier ?? 1,
        'active':       active ? 'S' : 'N',
        'tax':          (tax ?? const EntityTaxData()).toJson(),
      };

  /// Wrappers `Function()` nos anuláveis dos lookups/decimais permitem
  /// LIMPAR o valor (() => null) sem perder o padrão copyWith.
  @override
  ObjectCustomer copyWith({
    String? nameCompany,
    String? nickTrade,
    String? Function()? aniversary,
    List<EntityAddress>? addresses,
    List<EntityPhone>? phones,
    List<EntitySocialMedia>? socialMedia,
    String? personType,
    PersonData? person,
    CompanyData? company,
    NoDocData? noDoc,
    int? Function()? tbSalesmanId,
    String? Function()? salesmanName,
    int? Function()? tbCarrierId,
    String? Function()? carrierName,
    String? creditStatus,
    double? Function()? creditValue,
    String? wallet,
    double? Function()? multiplier,
    bool? active,
    EntityTaxData? tax,
  }) =>
      ObjectCustomer(
        id:           id,
        tbSalesmanId: tbSalesmanId != null ? tbSalesmanId() : this.tbSalesmanId,
        salesmanName: salesmanName != null ? salesmanName() : this.salesmanName,
        tbCarrierId:  tbCarrierId != null ? tbCarrierId() : this.tbCarrierId,
        carrierName:  carrierName != null ? carrierName() : this.carrierName,
        creditStatus: creditStatus ?? this.creditStatus,
        creditValue:  creditValue != null ? creditValue() : this.creditValue,
        wallet:       wallet ?? this.wallet,
        multiplier:   multiplier != null ? multiplier() : this.multiplier,
        active:       active ?? this.active,
        tax:          tax ?? this.tax,
        nameCompany:  nameCompany ?? this.nameCompany,
        nickTrade:    nickTrade ?? this.nickTrade,
        aniversary:   aniversary != null ? aniversary() : this.aniversary,
        addresses:    addresses ?? this.addresses,
        phones:       phones ?? this.phones,
        socialMedia:  socialMedia ?? this.socialMedia,
        personType:   personType ?? this.personType,
        person:       person ?? this.person,
        company:      company ?? this.company,
        noDoc:        noDoc ?? this.noDoc,
      );

  /// Merge da fatia editada pela EntityMainTab (aba compartilhada devolve
  /// ObjectEntityFiscal — os campos do concreto são preservados).
  ObjectCustomer mergeFiscal(ObjectEntityFiscal fiscal) => ObjectCustomer(
        id:           id,
        tbSalesmanId: tbSalesmanId,
        salesmanName: salesmanName,
        tbCarrierId:  tbCarrierId,
        carrierName:  carrierName,
        creditStatus: creditStatus,
        creditValue:  creditValue,
        wallet:       wallet,
        multiplier:   multiplier,
        active:       active,
        tax:          tax,
        nameCompany:  fiscal.nameCompany,
        nickTrade:    fiscal.nickTrade,
        aniversary:   fiscal.aniversary,
        addresses:    fiscal.addresses,
        phones:       fiscal.phones,
        socialMedia:  fiscal.socialMedia,
        personType:   fiscal.personType,
        person:       fiscal.person,
        company:      fiscal.company,
        noDoc:        fiscal.noDoc,
      );

  @override
  List<Object?> get props => [
        ...super.props, id, tbSalesmanId, salesmanName, tbCarrierId,
        carrierName, creditStatus, creditValue, wallet, multiplier,
        active, tax,
      ];
}
