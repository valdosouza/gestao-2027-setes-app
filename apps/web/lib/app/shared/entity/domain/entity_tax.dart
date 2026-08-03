import 'package:equatable/equatable.dart';

/// Fatia TRIBUTAÇÃO da relação comercial (tb_entity_tax — Fase 3 Rodada 4,
/// decisões 14–17). Nasceu no módulo customers e foi PROMOVIDA a
/// shared/entity na Onda 2 (D2: Carrier ganha a mesma aba — regra de
/// promoção da ARQUITETURA_MODULOS.md).
///
/// Radioboxes S/N viram String 'S'|'N'; checkboxes viram bool (serializados
/// 'S'/'N' no toJson); dropdowns gravam os valores canônicos
/// ([kTaxRegimes], [kIndIeDestCodes], [kIssExigibilidadeCodes]).

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
