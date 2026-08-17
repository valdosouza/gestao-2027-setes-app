import 'package:equatable/equatable.dart';

/// Linha da LISTA paginada de Regras de Tributação (GET /api/tax-rules) —
/// seletor resumido + flags de PRESENÇA das peças (hasIcms/hasIcmsSt/
/// hasIpi/hasPisCofins/hasIi). Presença = incidência (decisões 1/23 da
/// fase Faturamento Fiscal e Financeiro): a lista mostra quais tributos a
/// regra define sem carregar as peças inteiras.
class TaxRuleListItem extends Equatable {
  const TaxRuleListItem({
    required this.id,
    this.ncm,
    this.origin = '0',
    this.purpose = '0',
    this.st = 'N',
    this.finalConsumer = 'N',
    this.simples = 'N',
    this.productId,
    this.productName,
    this.entityId,
    this.stateId,
    this.stateName,
    this.cfopId,
    this.hasIcms = false,
    this.hasIcmsSt = false,
    this.hasIpi = false,
    this.hasPisCofins = false,
    this.hasIi = false,
  });

  final int id;
  final String? ncm;
  final String origin;
  final String purpose;
  final String st;
  final String finalConsumer;
  final String simples;
  final int? productId;
  final String? productName;
  final int? entityId;
  final int? stateId;
  final String? stateName;
  final String? cfopId;
  final bool hasIcms;
  final bool hasIcmsSt;
  final bool hasIpi;
  final bool hasPisCofins;
  final bool hasIi;

  factory TaxRuleListItem.fromJson(Map<String, dynamic> json) =>
      TaxRuleListItem(
        id:            (json['id'] as num).toInt(),
        ncm:           json['ncm'] as String?,
        origin:        json['origin'] as String? ?? '0',
        purpose:       json['purpose'] as String? ?? '0',
        st:            json['st'] as String? ?? 'N',
        finalConsumer: json['finalConsumer'] as String? ?? 'N',
        simples:       json['simples'] as String? ?? 'N',
        productId:     (json['productId'] as num?)?.toInt(),
        productName:   json['productName'] as String?,
        entityId:      (json['entityId'] as num?)?.toInt(),
        stateId:       (json['stateId'] as num?)?.toInt(),
        stateName:     json['stateName'] as String?,
        cfopId:        json['cfopId'] as String?,
        hasIcms:       json['hasIcms'] == true,
        hasIcmsSt:     json['hasIcmsSt'] == true,
        hasIpi:        json['hasIpi'] == true,
        hasPisCofins:  json['hasPisCofins'] == true,
        hasIi:         json['hasIi'] == true,
      );

  @override
  List<Object?> get props => [
        id, ncm, origin, purpose, st, finalConsumer, simples, productId,
        productName, entityId, stateId, stateName, cfopId,
        hasIcms, hasIcmsSt, hasIpi, hasPisCofins, hasIi,
      ];
}
