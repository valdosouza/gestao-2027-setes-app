import 'package:equatable/equatable.dart';

/// DRAFT da Regra de Tributação — espelho do body do POST/PUT /api/tax-rules
/// (taxRuleBodyDto): seletor + peças por tributo. PRESENÇA = incidência
/// (decisões 1/23 da fase): peça null = toggle desligado = tributo NÃO
/// definido pela regra — a chave é OMITIDA do payload (nunca objeto vazio).
///
/// Campos numéricos (alíquotas/reduções) vivem como TEXTO digitado ('' =
/// null) — a validação local (pendency R3) confere parse/faixa e o toJson
/// converte (vírgula aceita como separador decimal, padrão do app).

/// '' → null; vírgula → ponto (padrão dos decimais do app).
double? _numOrNull(String text) {
  final t = text.trim().replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

/// num? da API → texto do campo ('' = null; inteiro sem ".0").
String _textOf(num? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return '${value.toInt()}';
  return '$value';
}

String? _idOrNull(String? value) =>
    (value == null || value.isEmpty) ? null : value;

/// Seletor da regra (QUANDO ela vale — decisão 1). Campos vazios/null =
/// coringa. [observationId]/[taxesId] não têm campo na tela v1, mas são
/// PRESERVADOS na edição (o PUT substitui o seletor inteiro).
class TaxRuleSelectorData extends Equatable {
  const TaxRuleSelectorData({
    this.productId = '',
    this.entityId = '',
    this.ncm = '',
    this.origin = '0',
    this.finalConsumer = 'N',
    this.simples = 'N',
    this.st = 'N',
    this.purpose = '0',
    this.direction,
    this.cfopId = '',
    this.stateId,
    this.stateName = '',
    this.observationId,
    this.taxesId,
  });

  /// ids digitados como TEXTO ('' = coringa) — a pendency valida o parse.
  final String productId;
  final String entityId;
  final String ncm;
  final String origin;
  final String finalConsumer;
  final String simples;
  final String st;
  final String purpose;

  /// 'E'/'S'; null = ambos os sentidos.
  final String? direction;
  final String cfopId;
  final int? stateId;

  /// Nome do estado para EXIBIÇÃO no lookup (vem da lista/lookup — o GET
  /// :id da API devolve só o id).
  final String stateName;
  final int? observationId;
  final int? taxesId;

  factory TaxRuleSelectorData.fromJson(Map<String, dynamic> json) =>
      TaxRuleSelectorData(
        productId:     _textOf(json['productId'] as num?),
        entityId:      _textOf(json['entityId'] as num?),
        ncm:           json['ncm'] as String? ?? '',
        origin:        json['origin'] as String? ?? '0',
        finalConsumer: json['finalConsumer'] as String? ?? 'N',
        simples:       json['simples'] as String? ?? 'N',
        st:            json['st'] as String? ?? 'N',
        purpose:       json['purpose'] as String? ?? '0',
        direction:     json['direction'] as String?,
        cfopId:        json['cfopId'] as String? ?? '',
        stateId:       (json['stateId'] as num?)?.toInt(),
        observationId: (json['observationId'] as num?)?.toInt(),
        taxesId:       (json['taxesId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'productId':     int.tryParse(productId.trim()),
        'entityId':      int.tryParse(entityId.trim()),
        'ncm':           ncm.trim().isEmpty ? null : ncm.trim(),
        'origin':        origin,
        'finalConsumer': finalConsumer,
        'simples':       simples,
        'st':            st,
        'purpose':       purpose,
        'direction':     _idOrNull(direction),
        'cfopId':        cfopId.trim().isEmpty ? null : cfopId.trim(),
        'stateId':       stateId,
        'observationId': observationId,
        'taxesId':       taxesId,
      };

  TaxRuleSelectorData copyWith({
    String? productId,
    String? entityId,
    String? ncm,
    String? origin,
    String? finalConsumer,
    String? simples,
    String? st,
    String? purpose,
    String? Function()? direction,
    String? cfopId,
    int? Function()? stateId,
    String? stateName,
  }) =>
      TaxRuleSelectorData(
        productId:     productId ?? this.productId,
        entityId:      entityId ?? this.entityId,
        ncm:           ncm ?? this.ncm,
        origin:        origin ?? this.origin,
        finalConsumer: finalConsumer ?? this.finalConsumer,
        simples:       simples ?? this.simples,
        st:            st ?? this.st,
        purpose:       purpose ?? this.purpose,
        direction:     direction != null ? direction() : this.direction,
        cfopId:        cfopId ?? this.cfopId,
        stateId:       stateId != null ? stateId() : this.stateId,
        stateName:     stateName ?? this.stateName,
        observationId: observationId,
        taxesId:       taxesId,
      );

  @override
  List<Object?> get props => [
        productId, entityId, ncm, origin, finalConsumer, simples, st,
        purpose, direction, cfopId, stateId, stateName, observationId,
        taxesId,
      ];
}

/// Peça ICMS — CST (regime normal) e/ou CSOSN (Simples) obrigatório.
class IcmsData extends Equatable {
  const IcmsData({
    this.cstNr,
    this.csosn,
    this.modBc,
    this.dischargeId,
    this.aliq = '',
    this.aliqReduction = '',
    this.baseReduction = '',
    this.deferred = 'N',
    this.deferredAliq = '',
    this.highlight = 'N',
  });

  final String? cstNr;
  final String? csosn;
  final String? modBc;

  /// id do combo de desoneração como TEXTO ('' = não informado).
  final String? dischargeId;
  final String aliq;
  final String aliqReduction;
  final String baseReduction;
  final String deferred;
  final String deferredAliq;
  final String highlight;

  factory IcmsData.fromJson(Map<String, dynamic> json) => IcmsData(
        cstNr:         json['cstNr'] as String?,
        csosn:         json['csosn'] as String?,
        modBc:         json['modBc'] as String?,
        dischargeId:   json['dischargeId'] == null
            ? null
            : '${json['dischargeId']}',
        aliq:          _textOf(json['aliq'] as num?),
        aliqReduction: _textOf(json['aliqReduction'] as num?),
        baseReduction: _textOf(json['baseReduction'] as num?),
        deferred:      json['deferred'] as String? ?? 'N',
        deferredAliq:  _textOf(json['deferredAliq'] as num?),
        highlight:     json['highlight'] as String? ?? 'N',
      );

  Map<String, dynamic> toJson() => {
        'cstNr':         _idOrNull(cstNr),
        'csosn':         _idOrNull(csosn),
        'modBc':         _idOrNull(modBc),
        'dischargeId':   int.tryParse(dischargeId ?? ''),
        'aliq':          _numOrNull(aliq),
        'aliqReduction': _numOrNull(aliqReduction),
        'baseReduction': _numOrNull(baseReduction),
        'deferred':      deferred,
        // Sem diferimento o campo fica OCULTO na tela — o resquício
        // digitado não viaja (L1 dos gates).
        'deferredAliq':  deferred == 'S' ? _numOrNull(deferredAliq) : null,
        'highlight':     highlight,
      };

  IcmsData copyWith({
    String? Function()? cstNr,
    String? Function()? csosn,
    String? Function()? modBc,
    String? Function()? dischargeId,
    String? aliq,
    String? aliqReduction,
    String? baseReduction,
    String? deferred,
    String? deferredAliq,
    String? highlight,
  }) =>
      IcmsData(
        cstNr:         cstNr != null ? cstNr() : this.cstNr,
        csosn:         csosn != null ? csosn() : this.csosn,
        modBc:         modBc != null ? modBc() : this.modBc,
        dischargeId:   dischargeId != null ? dischargeId() : this.dischargeId,
        aliq:          aliq ?? this.aliq,
        aliqReduction: aliqReduction ?? this.aliqReduction,
        baseReduction: baseReduction ?? this.baseReduction,
        deferred:      deferred ?? this.deferred,
        deferredAliq:  deferredAliq ?? this.deferredAliq,
        highlight:     highlight ?? this.highlight,
      );

  @override
  List<Object?> get props => [
        cstNr, csosn, modBc, dischargeId, aliq, aliqReduction,
        baseReduction, deferred, deferredAliq, highlight,
      ];
}

/// Peça ICMS-ST — só faz sentido COM a peça ICMS ligada (422 da API).
class IcmsStData extends Equatable {
  const IcmsStData({this.modBcSt, this.propagateBaseReduction = 'N'});

  final String? modBcSt;
  final String propagateBaseReduction;

  factory IcmsStData.fromJson(Map<String, dynamic> json) => IcmsStData(
        modBcSt: json['modBcSt'] as String?,
        propagateBaseReduction:
            json['propagateBaseReduction'] as String? ?? 'N',
      );

  Map<String, dynamic> toJson() => {
        'modBcSt':                _idOrNull(modBcSt),
        'propagateBaseReduction': propagateBaseReduction,
      };

  IcmsStData copyWith({
    String? Function()? modBcSt,
    String? propagateBaseReduction,
  }) =>
      IcmsStData(
        modBcSt: modBcSt != null ? modBcSt() : this.modBcSt,
        propagateBaseReduction:
            propagateBaseReduction ?? this.propagateBaseReduction,
      );

  @override
  List<Object?> get props => [modBcSt, propagateBaseReduction];
}

/// Peça IPI — CST obrigatório quando a peça está ligada.
class IpiData extends Equatable {
  const IpiData({this.cst, this.aliq = ''});

  final String? cst;
  final String aliq;

  factory IpiData.fromJson(Map<String, dynamic> json) => IpiData(
        cst:  json['cst'] as String?,
        aliq: _textOf(json['aliq'] as num?),
      );

  Map<String, dynamic> toJson() => {
        'cst':  cst ?? '',
        'aliq': _numOrNull(aliq),
      };

  IpiData copyWith({String? Function()? cst, String? aliq}) => IpiData(
        cst:  cst != null ? cst() : this.cst,
        aliq: aliq ?? this.aliq,
      );

  @override
  List<Object?> get props => [cst, aliq];
}

/// Peça PIS ou COFINS — MESMA forma, [kind] distingue ('P'/'C', decisão 2:
/// "PIS = COFINS"). O payload junta as ligadas no array pisCofins.
class PisCofinsData extends Equatable {
  const PisCofinsData({required this.kind, this.cst, this.aliq = ''});

  final String kind;
  final String? cst;
  final String aliq;

  factory PisCofinsData.fromJson(Map<String, dynamic> json) => PisCofinsData(
        kind: json['kind'] as String? ?? 'P',
        cst:  json['cst'] as String?,
        aliq: _textOf(json['aliq'] as num?),
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'cst':  cst ?? '',
        'aliq': _numOrNull(aliq),
      };

  PisCofinsData copyWith({String? Function()? cst, String? aliq}) =>
      PisCofinsData(
        kind: kind,
        cst:  cst != null ? cst() : this.cst,
        aliq: aliq ?? this.aliq,
      );

  @override
  List<Object?> get props => [kind, cst, aliq];
}

/// Peça II (Importação) — alíquotas do desembaraço (AFRMM/SISCOMEX com 5
/// casas decimais).
class IiData extends Equatable {
  const IiData({
    this.iiAliq = '',
    this.irpjAliq = '',
    this.csllAliq = '',
    this.afrmmAliq = '',
    this.siscomexAliq = '',
  });

  final String iiAliq;
  final String irpjAliq;
  final String csllAliq;
  final String afrmmAliq;
  final String siscomexAliq;

  factory IiData.fromJson(Map<String, dynamic> json) => IiData(
        iiAliq:       _textOf(json['iiAliq'] as num?),
        irpjAliq:     _textOf(json['irpjAliq'] as num?),
        csllAliq:     _textOf(json['csllAliq'] as num?),
        afrmmAliq:    _textOf(json['afrmmAliq'] as num?),
        siscomexAliq: _textOf(json['siscomexAliq'] as num?),
      );

  Map<String, dynamic> toJson() => {
        'iiAliq':       _numOrNull(iiAliq),
        'irpjAliq':     _numOrNull(irpjAliq),
        'csllAliq':     _numOrNull(csllAliq),
        'afrmmAliq':    _numOrNull(afrmmAliq),
        'siscomexAliq': _numOrNull(siscomexAliq),
      };

  IiData copyWith({
    String? iiAliq,
    String? irpjAliq,
    String? csllAliq,
    String? afrmmAliq,
    String? siscomexAliq,
  }) =>
      IiData(
        iiAliq:       iiAliq ?? this.iiAliq,
        irpjAliq:     irpjAliq ?? this.irpjAliq,
        csllAliq:     csllAliq ?? this.csllAliq,
        afrmmAliq:    afrmmAliq ?? this.afrmmAliq,
        siscomexAliq: siscomexAliq ?? this.siscomexAliq,
      );

  @override
  List<Object?> get props =>
      [iiAliq, irpjAliq, csllAliq, afrmmAliq, siscomexAliq];
}

/// Objeto completo do formulário: seletor + peças presentes. As abas de
/// tributo editam a própria fatia; toggle desligado = fatia null.
class TaxRuleDraft extends Equatable {
  const TaxRuleDraft({
    this.id,
    this.selector = const TaxRuleSelectorData(),
    this.icms,
    this.icmsSt,
    this.ipi,
    this.pis,
    this.cofins,
    this.ii,
  });

  /// null na criação (id = MAX+1 no backend, campo não exibido).
  final int? id;
  final TaxRuleSelectorData selector;
  final IcmsData? icms;
  final IcmsStData? icmsSt;
  final IpiData? ipi;
  final PisCofinsData? pis;
  final PisCofinsData? cofins;
  final IiData? ii;

  /// GET /api/tax-rules/:id → { selector, pieces } (o array pisCofins é
  /// aberto em fatias P/C — decisão "PIS = COFINS", mesma aba).
  factory TaxRuleDraft.fromJson(Map<String, dynamic> json) {
    final selector = json['selector'] as Map<String, dynamic>? ?? const {};
    final pieces = json['pieces'] as Map<String, dynamic>? ?? const {};
    PisCofinsData? pis;
    PisCofinsData? cofins;
    for (final raw in pieces['pisCofins'] as List<dynamic>? ?? const []) {
      final piece = PisCofinsData.fromJson(raw as Map<String, dynamic>);
      // Kind duplicado vindo do banco: a PRIMEIRA ocorrência vale
      // (determinístico — L5 dos gates; o DTO da API já rejeita na escrita).
      if (piece.kind == 'P') {
        pis ??= piece;
      } else {
        cofins ??= piece;
      }
    }
    return TaxRuleDraft(
      id:       (selector['id'] as num?)?.toInt(),
      selector: TaxRuleSelectorData.fromJson(selector),
      icms:     pieces['icms'] == null
          ? null
          : IcmsData.fromJson(pieces['icms'] as Map<String, dynamic>),
      icmsSt:   pieces['icmsSt'] == null
          ? null
          : IcmsStData.fromJson(pieces['icmsSt'] as Map<String, dynamic>),
      ipi:      pieces['ipi'] == null
          ? null
          : IpiData.fromJson(pieces['ipi'] as Map<String, dynamic>),
      pis:      pis,
      cofins:   cofins,
      ii:       pieces['ii'] == null
          ? null
          : IiData.fromJson(pieces['ii'] as Map<String, dynamic>),
    );
  }

  /// true quando ao menos um TRIBUTO está ligado (o ICMS-ST sozinho não
  /// conta — espelho do refine do DTO da API).
  bool get hasAnyPiece =>
      icms != null || ipi != null || pis != null || cofins != null ||
      ii != null;

  /// Body do POST/PUT — peça desligada é OMITIDA (presença = incidência).
  Map<String, dynamic> toJson() => {
        'selector': selector.toJson(),
        if (icms != null) 'icms': icms!.toJson(),
        if (icmsSt != null) 'icmsSt': icmsSt!.toJson(),
        if (ipi != null) 'ipi': ipi!.toJson(),
        if (pis != null || cofins != null)
          'pisCofins': [
            if (pis != null) pis!.toJson(),
            if (cofins != null) cofins!.toJson(),
          ],
        if (ii != null) 'ii': ii!.toJson(),
      };

  TaxRuleDraft copyWith({
    TaxRuleSelectorData? selector,
    IcmsData? Function()? icms,
    IcmsStData? Function()? icmsSt,
    IpiData? Function()? ipi,
    PisCofinsData? Function()? pis,
    PisCofinsData? Function()? cofins,
    IiData? Function()? ii,
  }) =>
      TaxRuleDraft(
        id:       id,
        selector: selector ?? this.selector,
        icms:     icms != null ? icms() : this.icms,
        icmsSt:   icmsSt != null ? icmsSt() : this.icmsSt,
        ipi:      ipi != null ? ipi() : this.ipi,
        pis:      pis != null ? pis() : this.pis,
        cofins:   cofins != null ? cofins() : this.cofins,
        ii:       ii != null ? ii() : this.ii,
      );

  @override
  List<Object?> get props =>
      [id, selector, icms, icmsSt, ipi, pis, cofins, ii];
}
