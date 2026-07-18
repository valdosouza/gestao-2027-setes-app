import 'package:equatable/equatable.dart';

/// Código de pagamento da NF-e/NFC-e — LISTA FISCAL FIXA (tabela do
/// leiaute da NF-e; combobox no form grava só os 2 dígitos). Descrições
/// oficiais em PT — domínio fiscal brasileiro, sem i18n.
class NfceCode {
  const NfceCode(this.code, this.label);

  final String code;
  final String label;

  String get display => '$code - $label';

  static const List<NfceCode> all = [
    NfceCode('01', 'Dinheiro'),
    NfceCode('02', 'Cheque'),
    NfceCode('03', 'Cartão de Crédito'),
    NfceCode('04', 'Cartão de Débito'),
    NfceCode('05', 'Cartão da Loja (Private Label)'),
    NfceCode('10', 'Vale Alimentação'),
    NfceCode('11', 'Vale Refeição'),
    NfceCode('12', 'Vale Presente'),
    NfceCode('13', 'Vale Combustível'),
    NfceCode('14', 'Duplicata Mercantil'),
    NfceCode('15', 'Boleto Bancário'),
    NfceCode('16', 'Depósito Bancário'),
    NfceCode('17', 'Pagamento Instantâneo (PIX) - Dinâmico'),
    NfceCode('18', 'Transferência bancária, Carteira Digital'),
    NfceCode('19', 'Programa de fidelidade, Cashback, Crédito Virtual'),
    NfceCode('20', 'Pagamento Instantâneo (PIX) - Estático'),
    NfceCode('21', 'Crédito em Loja'),
    NfceCode('22',
        'Pagamento Eletrônico não Informado - falha de hardware do sistema emissor'),
    NfceCode('90', 'Sem Pagamento'),
    NfceCode('99', 'Outros'),
  ];

  /// "01 - Dinheiro" para exibição; código desconhecido volta cru.
  static String displayOf(String? code) {
    if (code == null || code.isEmpty) return '';
    for (final item in all) {
      if (item.code == code) return item.display;
    }
    return code;
  }
}

/// Atributos do VÍNCULO institution × forma (migration 012 —
/// tb_institution_has_payment_types). [enable] substitui o antigo active:
/// a linha do catálogo é compartilhada, o cliente desabilita por um tempo,
/// não exclui. [usagePreference]: lançamento em 'C'aixa/'B'anco/'A'mbos.
/// Planos de conta 0 = não definido (referência sem FK física).
class PaymentTypeLinkAttrs extends Equatable {
  const PaymentTypeLinkAttrs({
    this.enable = true,
    this.appMobile = false,
    this.blockForCustomerBlocked = false,
    this.blockForCustomerNoLimit = false,
    this.maxParcels = 1,
    this.tef = false,
    this.financialPlansIdCre = 0,
    this.financialPlansIdDeb = 0,
    this.usagePreference = 'A',
  });

  final bool enable;

  /// Disponível no app mobile (ex-appDelivery).
  final bool appMobile;

  /// Não mostrar para clientes bloqueados.
  final bool blockForCustomerBlocked;

  /// Bloquear para clientes sem limite de crédito.
  final bool blockForCustomerNoLimit;

  /// Número máximo de parcelas permitidas.
  final int maxParcels;

  /// Usa TEF — Transferência Eletrônica de Fundos.
  final bool tef;

  /// Plano de Contas — Resultado (kind 'R'; 0 = não definido).
  final int financialPlansIdCre;

  /// Plano de Contas — Centro de Custo (kind 'C'; 0 = não definido).
  final int financialPlansIdDeb;

  /// 'C' Caixa / 'B' Banco / 'A' Ambos.
  final String usagePreference;

  factory PaymentTypeLinkAttrs.fromJson(Map<String, dynamic> json) =>
      PaymentTypeLinkAttrs(
        enable:    (json['enable'] as String?) != 'N',
        appMobile: (json['appMobile'] as String?) == 'S',
        blockForCustomerBlocked:
            (json['blockForCustomerBlocked'] as String?) == 'S',
        blockForCustomerNoLimit:
            (json['blockForCustomerNoLimit'] as String?) == 'S',
        maxParcels: (json['maxParcels'] as num?)?.toInt() ?? 1,
        tef:        (json['tef'] as String?) == 'S',
        financialPlansIdCre:
            (json['financialPlansIdCre'] as num?)?.toInt() ?? 0,
        financialPlansIdDeb:
            (json['financialPlansIdDeb'] as num?)?.toInt() ?? 0,
        usagePreference: json['usagePreference'] as String? ?? 'A',
      );

  Map<String, dynamic> toJson() => {
        'enable':                  enable ? 'S' : 'N',
        'appMobile':               appMobile ? 'S' : 'N',
        'blockForCustomerBlocked': blockForCustomerBlocked ? 'S' : 'N',
        'blockForCustomerNoLimit': blockForCustomerNoLimit ? 'S' : 'N',
        'maxParcels':              maxParcels,
        'tef':                     tef ? 'S' : 'N',
        'financialPlansIdCre':     financialPlansIdCre,
        'financialPlansIdDeb':     financialPlansIdDeb,
        'usagePreference':         usagePreference,
      };

  @override
  List<Object?> get props => [
        enable, appMobile, blockForCustomerBlocked, blockForCustomerNoLimit,
        maxParcels, tef, financialPlansIdCre, financialPlansIdDeb,
        usagePreference,
      ];
}

/// Forma de pagamento VINCULADA à institution (workflow do Valdo,
/// 2026-07-18): o catálogo é CENTRAL e compartilhado
/// (setes_central.tb_payment_types — o cliente inicia o cadastro; existente
/// = só vincula, reuso entre clientes); o vínculo/uso vive no schema
/// (tb_institution_has_payment_types: [attrs]).
/// description é IMUTÁVEL depois de criada (chave do reuso na linha
/// compartilhada); idNfce é editável — o PUT atualiza a linha central.
class LinkedPaymentType extends Equatable {
  const LinkedPaymentType({
    required this.id,
    this.description,
    this.idNfce,
    this.attrs = const PaymentTypeLinkAttrs(),
    this.financialPlanCreDescription,
    this.financialPlanDebDescription,
  });

  final int     id;
  final String? description;

  /// Código de pagamento da NF-e (2 dígitos — [NfceCode.all]).
  final String? idNfce;

  final PaymentTypeLinkAttrs attrs;

  /// Descrições dos Planos de Conta escolhidos (JOIN da API — só exibição).
  final String? financialPlanCreDescription;
  final String? financialPlanDebDescription;

  factory LinkedPaymentType.fromJson(Map<String, dynamic> json) =>
      LinkedPaymentType(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String?,
        idNfce:      json['idNfce'] as String?,
        attrs:       PaymentTypeLinkAttrs.fromJson(json),
        financialPlanCreDescription:
            json['financialPlanCreDescription'] as String?,
        financialPlanDebDescription:
            json['financialPlanDebDescription'] as String?,
      );

  @override
  List<Object?> get props => [
        id, description, idNfce, attrs,
        financialPlanCreDescription, financialPlanDebDescription,
      ];
}

/// Linha do catálogo CENTRAL (lookup do form) — marca as já vinculadas.
class PaymentTypeCatalogItem extends Equatable {
  const PaymentTypeCatalogItem({
    required this.id,
    this.description,
    this.idNfce,
    this.linked = false,
  });

  final int     id;
  final String? description;
  final String? idNfce;
  final bool    linked;

  factory PaymentTypeCatalogItem.fromJson(Map<String, dynamic> json) =>
      PaymentTypeCatalogItem(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String?,
        idNfce:      json['idNfce'] as String?,
        linked:      (json['linked'] as String?) == 'S',
      );

  @override
  List<Object?> get props => [id, description, idNfce, linked];
}

/// Conta do Plano de Contas para os lookups do form (kind 'R' = Resultado,
/// 'C' = Centro de Custo) — projeção local do /api/financial-plans (módulo
/// nunca importa módulo).
class FinancialPlanLookupItem extends Equatable {
  const FinancialPlanLookupItem({
    required this.id,
    required this.description,
    this.positLevel = '',
    this.kind = 'C',
    this.active = true,
  });

  final int    id;
  final String description;

  /// Caminho materializado na árvore (ex.: "001.002").
  final String positLevel;

  /// 'C' Centro de Custo / 'R' Contas de Resultado.
  final String kind;
  final bool   active;

  String get display =>
      positLevel.isEmpty ? description : '$positLevel — $description';

  factory FinancialPlanLookupItem.fromJson(Map<String, dynamic> json) =>
      FinancialPlanLookupItem(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String? ?? '',
        positLevel:  json['positLevel'] as String? ?? '',
        kind:        json['kind'] as String? ?? 'C',
        active:      (json['active'] as String?) != 'N',
      );

  @override
  List<Object?> get props => [id, description, positLevel, kind, active];
}

/// Resultado do POST: [reused] = a forma já existia no catálogo central
/// (foi apenas vinculada — mesmo espírito do reuso da entidade única).
class PaymentTypePostResult extends Equatable {
  const PaymentTypePostResult({required this.id, required this.reused});

  final int  id;
  final bool reused;

  @override
  List<Object?> get props => [id, reused];
}
