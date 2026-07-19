import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo contracts — Contratos de serviço (Módulo Software
/// House, prompt_modulo_software_house.md; Valdo 2026-07-18). Espelho do
/// /api/contracts: contrato por cliente com N itens (produto + valor
/// MENSAL); a mensalidade é DERIVADA (soma dos itens — DP3, sem campo
/// redundante). Datas trafegam em ISO 'yyyy-MM-dd'; payment_day é
/// INFORMATIVO (DP1 — o vencimento real é definido no faturamento).
/// Formato de moeda: `setesMoney` em `app/shared/format/money.dart`
/// (promovida do antigo contractMoney no 2º consumidor — service_orders).

/// Linha da PESQUISA (GET /api/contracts) — nome do cliente via JOIN da
/// API; [monthlyValue] = SUM dos itens calculada no SQL.
class ContractListItem extends Equatable {
  const ContractListItem({
    required this.id,
    required this.customerId,
    this.customerName,
    this.dtStart = '',
    this.dtEnd,
    this.monthlyValue = 0,
    this.active = true,
  });

  final int     id;
  final int     customerId;
  final String? customerName;

  /// ISO 'yyyy-MM-dd'.
  final String  dtStart;

  /// ISO 'yyyy-MM-dd'; null = contrato sem data final (vigente).
  final String? dtEnd;

  /// Mensalidade = soma dos valores dos itens (derivada na API).
  final double  monthlyValue;
  final bool    active;

  factory ContractListItem.fromJson(Map<String, dynamic> json) =>
      ContractListItem(
        id:           jsonInt(json['id']) ?? 0,
        customerId:   jsonInt(json['customerId']) ?? 0,
        customerName: json['customerName'] as String?,
        dtStart:      json['dtStart'] as String? ?? '',
        dtEnd:        json['dtEnd'] as String?,
        monthlyValue: jsonDouble(json['monthlyValue']) ?? 0,
        active:       (json['active'] as String?) != 'N',
      );

  @override
  List<Object?> get props =>
      [id, customerId, customerName, dtStart, dtEnd, monthlyValue, active];
}

/// Item do contrato (tb_contract_item): produto ÚNICO por contrato com
/// valor MENSAL próprio (D9 — a essência do contrato são os itens).
class ContractItem extends Equatable {
  const ContractItem({
    required this.productId,
    this.productDescription,
    this.value = 0,
  });

  final int     productId;

  /// Descrição do produto (JOIN da API — só exibição).
  final String? productDescription;

  /// Valor mensal do item (>= 0).
  final double  value;

  factory ContractItem.fromJson(Map<String, dynamic> json) => ContractItem(
        productId:          jsonInt(json['productId']) ?? 0,
        productDescription: json['productDescription'] as String?,
        value:              jsonDouble(json['value']) ?? 0,
      );

  @override
  List<Object?> get props => [productId, productDescription, value];
}

/// Contrato COMPLETO (GET /api/contracts/:id) — a lista não traz itens
/// nem paymentDay; a edição carrega o objeto cheio.
class ContractFull extends Equatable {
  const ContractFull({
    required this.id,
    required this.customerId,
    this.customerName,
    this.dtStart = '',
    this.dtEnd,
    this.paymentDay = 5,
    this.active = true,
    this.items = const [],
  });

  final int     id;
  final int     customerId;
  final String? customerName;
  final String  dtStart;
  final String? dtEnd;

  /// Dia de vencimento 1..28 — INFORMATIVO (DP1).
  final int     paymentDay;
  final bool    active;
  final List<ContractItem> items;

  factory ContractFull.fromJson(Map<String, dynamic> json) => ContractFull(
        id:           jsonInt(json['id']) ?? 0,
        customerId:   jsonInt(json['customerId']) ?? 0,
        customerName: json['customerName'] as String?,
        dtStart:      json['dtStart'] as String? ?? '',
        dtEnd:        json['dtEnd'] as String?,
        paymentDay:   jsonInt(json['paymentDay']) ?? 5,
        active:       (json['active'] as String?) != 'N',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => ContractItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props =>
      [id, customerId, customerName, dtStart, dtEnd, paymentDay, active, items];
}

/// Body do POST/PUT — itens SEMPRE completos (a API sincroniza por
/// productId). O app NUNCA envia a mensalidade (derivada — DP3).
class ContractInput extends Equatable {
  const ContractInput({
    required this.customerId,
    required this.dtStart,
    this.dtEnd,
    this.paymentDay = 5,
    this.active = true,
    this.items = const [],
  });

  final int     customerId;
  final String  dtStart;
  final String? dtEnd;
  final int     paymentDay;
  final bool    active;
  final List<ContractItem> items;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'dtStart':    dtStart,
        'dtEnd':      dtEnd,
        'paymentDay': paymentDay,
        'active':     active ? 'S' : 'N',
        'items': [
          for (final item in items)
            {'productId': item.productId, 'value': item.value},
        ],
      };

  @override
  List<Object?> get props =>
      [customerId, dtStart, dtEnd, paymentDay, active, items];
}

/// Cliente para o lookup do form (GET /api/customers — projeção local:
/// módulo nunca importa módulo).
class ContractCustomerLookup extends Equatable {
  const ContractCustomerLookup({
    required this.id,
    this.nickTrade,
    this.nameCompany,
    this.active = true,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;
  final bool    active;

  /// Exibição: nome fantasia, senão razão social.
  String get display => nickTrade ?? nameCompany ?? '';

  factory ContractCustomerLookup.fromJson(Map<String, dynamic> json) =>
      ContractCustomerLookup(
        id:          jsonInt(json['id']) ?? 0,
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
        active:      (json['active'] as String?) == 'S',
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany, active];
}

/// Produto/serviço ATIVO para o lookup dos itens
/// (GET /api/contracts/products).
class ContractProductLookup extends Equatable {
  const ContractProductLookup({required this.id, this.description = ''});

  final int    id;
  final String description;

  factory ContractProductLookup.fromJson(Map<String, dynamic> json) =>
      ContractProductLookup(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, description];
}
