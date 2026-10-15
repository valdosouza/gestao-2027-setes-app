import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../entity/widgets/entity_date.dart';

/// Peça compartilhada da DECLARAÇÃO IBS/CBS (fase IBS/CBS, IB-3 — D-IB75/D-IB76): as formas que a API devolve e UM cartão que só as
/// RENDERIZA. O app nunca calcula omissão, obrigação nem divergência — tudo vem pronto do setes-api (resultado do faturamento, relatório do
/// lote, prévia do validate/OS aberta, declaração congelada da OS faturada) e da nfse-api (declaração enviada + valores do fisco).
/// Os motivos da omissão são a lista FECHADA da API (`IBSCBS_OMISSIONS` — D-IB91), espelhada em [kIbscbsOmissions] e traduzida por i18n
/// (`ibscbs.omitted.<motivo>`). Gates da IB-3 (ADV-IB3X-01…03): parse TOLERANTE (tipo trocado = vazio/null, nunca exceção — uma linha do
/// lote não derruba o relatório) e valor do fisco formatado do TEXTO exato (nunca `double`; ilegível = "—", nunca "R$ 0,00").

/// Espelho versionado da lista FECHADA de motivos da API (`IBSCBS_OMISSIONS` em `@shared/ibscbs-classification`) — o teste
/// `ibscbs_ib3_test.dart` confere este espelho contra a constante da API e contra as chaves i18n (D-IB91).
const kIbscbsOmissions = <String>[
  'not-classified', 'no-line', 'not-applicable', 'requires-regular',
  'place-indicator', 'nbs-missing', 'nbs-not-accepted', 'divergent',
];

String? _str(dynamic v) => v is String ? v : null;
List<String> _reasons(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const <String>[];
Map<String, dynamic>? _map(dynamic v) => v is Map<String, dynamic> ? v : null;

/// Motivo da omissão → texto (motivo desconhecido aparece cru: a lista é da API).
String ibscbsOmissionText(String reason) {
  final key = 'ibscbs.omitted.$reason';
  final t = key.tr();
  return t == key ? reason : t;
}

String _reasonsText(List<String> omitted) => omitted.map(ibscbsOmissionText).join('; ');

/// O que o FATURAMENTO decidiu (resultado da OS/venda e linha do lote — D-IB65).
class IbscbsOutcome extends Equatable {
  const IbscbsOutcome({required this.declared, this.omitted = const []});

  /// true = o grupo IBS/CBS foi CONGELADO na nota (vai ao fisco a partir da IB-3).
  final bool declared;
  final List<String> omitted;

  /// O predicado ÚNICO "a nota saiu SEM o grupo" — bloc, página e relatório do lote perguntam aqui (gate socrático, L7).
  bool get leftWithoutGroup => !declared;

  /// Os motivos, prontos para a mensagem.
  String get reasonsText => _reasonsText(omitted);

  static IbscbsOutcome? fromJson(dynamic json) {
    final m = _map(json);
    return m == null ? null : IbscbsOutcome(declared: m['declared'] == true, omitted: _reasons(m['omitted']));
  }

  @override
  List<Object?> get props => [declared, omitted];
}

/// Um veredito da composição (hoje ou na data da obrigação).
class IbscbsVerdict extends Equatable {
  const IbscbsVerdict({required this.declared, this.omitted = const [], this.refusalCode, this.refusalMessage});

  final bool declared;
  final List<String> omitted;

  /// A recusa que o faturamento daria (o MESMO texto do 422).
  final String? refusalCode;
  final String? refusalMessage;

  bool get refused => refusalMessage != null;

  static IbscbsVerdict? fromJson(dynamic json) {
    final m = _map(json);
    if (m == null) return null;
    final refusal = _map(m['refusal']);
    return IbscbsVerdict(
      declared: m['declared'] == true,
      omitted: _reasons(m['omitted']),
      refusalCode: refusal?['code']?.toString(),
      refusalMessage: refusal?['message']?.toString(),
    );
  }

  @override
  List<Object?> get props => [declared, omitted, refusalCode, refusalMessage];
}

/// A declaração PREVISTA antes de faturar (validate da venda, detalhe da OS aberta — D-IB76): o veredito de HOJE (a data que o
/// faturamento usaria) + antes da obrigação o veredito NA DATA DA OBRIGAÇÃO (D-IB89).
class IbscbsPreview extends Equatable {
  const IbscbsPreview({
    required this.competenceDate,
    required this.obligationStart,
    required this.obligatory,
    required this.today,
    this.atObligation,
  });

  /// ISO 'yyyy-MM-dd' — a data a que a prévia se refere (o operador vê se ela envelheceu — L1).
  final String competenceDate;
  final String obligationStart;
  final bool obligatory;
  final IbscbsVerdict today;
  final IbscbsVerdict? atObligation;

  bool get declared => today.declared;
  List<String> get omitted => today.omitted;
  bool get refused => today.refused;
  String? get refusalCode => today.refusalCode;
  String? get refusalMessage => today.refusalMessage;

  static IbscbsPreview? fromJson(dynamic json) {
    final m = _map(json);
    if (m == null) return null;
    return IbscbsPreview(
      competenceDate: _str(m['competenceDate']) ?? '',
      obligationStart: _str(m['obligationStart']) ?? '',
      obligatory: m['obligatory'] == true,
      today: IbscbsVerdict.fromJson(m)!,
      atObligation: IbscbsVerdict.fromJson(m['atObligation']),
    );
  }

  @override
  List<Object?> get props => [competenceDate, obligationStart, obligatory, today, atObligation];
}

/// A declaração CONGELADA no ramo da nota faturada (ERP — lida, nunca recalculada).
class IbscbsFrozen extends Equatable {
  const IbscbsFrozen({this.classificationCode, this.placeIndicatorCode, this.nbs});

  final String? classificationCode;
  final String? placeIndicatorCode;
  final String? nbs;

  bool get hasGroup => classificationCode != null && placeIndicatorCode != null;

  static IbscbsFrozen? fromJson(dynamic json) {
    final m = _map(json);
    return m == null
        ? null
        : IbscbsFrozen(
            classificationCode: _str(m['classificationCode']),
            placeIndicatorCode: _str(m['placeIndicatorCode']),
            nbs: _str(m['nbs']),
          );
  }

  @override
  List<Object?> get props => [classificationCode, placeIndicatorCode, nbs];
}

/// O bloco da OS: prevista (aberta) OU congelada (faturada); [unavailable] = a leitura falhou no servidor (D-IB87 — o resto do detalhe
/// segue).
class IbscbsOrderView extends Equatable {
  const IbscbsOrderView({this.preview, this.frozen, this.unavailable = false});

  final IbscbsPreview? preview;
  final IbscbsFrozen? frozen;
  final bool unavailable;

  static IbscbsOrderView? fromJson(dynamic json) {
    final m = _map(json);
    return m == null
        ? null
        : IbscbsOrderView(
            preview: IbscbsPreview.fromJson(m['preview']),
            frozen: IbscbsFrozen.fromJson(m['frozen']),
            unavailable: m['unavailable'] == true,
          );
  }

  @override
  List<Object?> get props => [preview, frozen, unavailable];
}

/// O que a nfse-api mostra da NFS-e: a declaração ENVIADA (do XML), se o DPS autorizado levou o grupo ([groupInDps] — D-IB90) e os
/// VALORES que o fisco calculou (texto decimal exato).
class IbscbsFiscal extends Equatable {
  const IbscbsFiscal({
    this.cst,
    this.classificationCode,
    this.placeIndicatorCode,
    this.nbs,
    this.groupInDps,
    this.totalInvoiceValue,
    this.ibsTotalValue,
    this.cbsValue,
  });

  final String? cst;
  final String? classificationCode;
  final String? placeIndicatorCode;
  final String? nbs;

  /// true = o DPS autorizado levou o grupo · false = NÃO levou · null = XML indisponível (nfse-api).
  final bool? groupInDps;
  final String? totalInvoiceValue;
  final String? ibsTotalValue;
  final String? cbsValue;

  bool get hasDeclared => classificationCode != null;
  bool get hasValues => totalInvoiceValue != null;

  static IbscbsFiscal? fromJson(dynamic json) {
    final m = _map(json);
    if (m == null) return null;
    final d = _map(m['declared']);
    final v = _map(m['values']);
    final g = m['groupInDps'];
    return IbscbsFiscal(
      cst: _str(d?['cst']),
      classificationCode: _str(d?['classificationCode']),
      placeIndicatorCode: _str(d?['placeIndicatorCode']),
      nbs: _str(d?['nbs']),
      groupInDps: g is bool ? g : null,
      totalInvoiceValue: v?['totalInvoiceValue']?.toString(),
      ibsTotalValue: v?['ibsTotalValue']?.toString(),
      cbsValue: v?['cbsValue']?.toString(),
    );
  }

  @override
  List<Object?> get props => [cst, classificationCode, placeIndicatorCode, nbs, groupInDps, totalInvoiceValue, ibsTotalValue, cbsValue];
}

/// Valor do fisco (TSDec15V2: até 15 inteiros, 2 casas) formatado do TEXTO — nunca `double` (perde centavos acima de ~1e13); fora da forma
/// ("NaN", "Infinity", notação científica, negativo, ausente) = "—", nunca "R$ 0,00" (ADV-IB3X-01/02).
final _decText = RegExp(r'^(0|[1-9]\d{0,14})(?:\.(\d{1,2}))?$');
String ibscbsMoney(String? v) {
  final m = v == null ? null : _decText.firstMatch(v);
  if (m == null) return '—';
  final units = m.group(1)!;
  final cents = '${m.group(2) ?? ''}00'.substring(0, 2);
  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) grouped.write('.');
    grouped.write(units[i]);
  }
  return 'R\$ $grouped,$cents';
}

/// Texto da prévia de HOJE (uma linha legível) — o cartão e o diálogo da venda usam o MESMO.
String ibscbsPreviewText(IbscbsPreview p) {
  if (p.refused) return p.refusalMessage!;
  if (p.declared) return 'ibscbs.previewDeclared'.tr();
  return 'ibscbs.previewOmitted'.tr(args: [isoDateToDisplay(p.obligationStart), _reasonsText(p.omitted)]);
}

/// D-IB89: o veredito na data da obrigação (null quando não há — depois da obrigação o de hoje já é ele).
String? ibscbsAtObligationText(IbscbsPreview p) {
  final a = p.atObligation;
  if (a == null) return null;
  final date = isoDateToDisplay(p.obligationStart);
  if (a.refused) return 'ibscbs.atObligationRefused'.tr(args: [date, a.refusalMessage!]);
  if (a.declared) return 'ibscbs.atObligationDeclared'.tr(args: [date]);
  return 'ibscbs.atObligationOmitted'.tr(args: [date, _reasonsText(a.omitted)]);
}

/// Texto do resultado do faturamento (linha do lote, mensagem de sucesso).
String ibscbsOutcomeText(IbscbsOutcome o) =>
    o.leftWithoutGroup ? 'ibscbs.outcomeOmitted'.tr(args: [o.reasonsText]) : 'ibscbs.outcomeDeclared'.tr();

/// Cartão "IBS/CBS" — só renderiza (prevista · congelada · enviada + valores do fisco · indisponível). Nada aqui decide.
class IbscbsCard extends StatelessWidget {
  const IbscbsCard({this.preview, this.frozen, this.fiscal, this.unavailable = false, super.key});

  final IbscbsPreview? preview;
  final IbscbsFrozen? frozen;
  final IbscbsFiscal? fiscal;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = <Widget>[];
    Color? tone;
    IconData icon = Icons.receipt_long_outlined;
    if (unavailable) {
      tone = scheme.outline;
      icon = Icons.cloud_off_outlined;
      lines.add(Text('ibscbs.unavailable'.tr(), key: const Key('ibscbs-unavailable')));
    }
    final p = preview;
    if (p != null) {
      final aheadRefused = p.atObligation?.refused ?? false;
      tone = p.refused || aheadRefused ? scheme.error : (p.declared ? null : scheme.tertiary);
      icon = p.refused ? Icons.error_outline : (p.declared && !aheadRefused ? Icons.check_circle_outline : Icons.info_outline);
      lines.add(Text('ibscbs.previewFor'.tr(args: [isoDateToDisplay(p.competenceDate)]), key: const Key('ibscbs-preview-date')));
      lines.add(Text(ibscbsPreviewText(p), key: const Key('ibscbs-preview')));
      final aheadText = ibscbsAtObligationText(p);
      if (aheadText != null) lines.add(Text(aheadText, key: const Key('ibscbs-at-obligation')));
    }
    final f = frozen;
    if (f != null) {
      lines.add(Text(
        f.hasGroup
            ? 'ibscbs.frozenDeclared'.tr(args: [f.classificationCode!, f.placeIndicatorCode!, f.nbs ?? '—'])
            : 'ibscbs.frozenOmitted'.tr(args: [f.nbs ?? '—']),
        key: const Key('ibscbs-frozen'),
      ));
    }
    final x = fiscal;
    if (x != null) {
      // D-IB90: congelada no ERP × o DPS autorizado SEM o grupo — dito como tal (o app não decide; a nfse-api disse o que o DPS levou)
      if (f != null && f.hasGroup && x.groupInDps == false) {
        tone = scheme.error;
        icon = Icons.warning_amber_outlined;
        lines.add(Text('ibscbs.sentWithoutGroup'.tr(), key: const Key('ibscbs-sent-without-group')));
      }
      if (x.hasDeclared) {
        lines.add(Text('ibscbs.sent'.tr(args: [x.cst ?? '—', x.classificationCode!, x.placeIndicatorCode ?? '—', x.nbs ?? '—']),
            key: const Key('ibscbs-sent')));
      }
      if (x.hasValues) {
        lines.add(Text(
          'ibscbs.fiscalValues'.tr(args: [ibscbsMoney(x.ibsTotalValue), ibscbsMoney(x.cbsValue), ibscbsMoney(x.totalInvoiceValue)]),
          key: const Key('ibscbs-values'),
        ));
      } else if (x.hasDeclared) {
        lines.add(Text('ibscbs.fiscalValuesPending'.tr(), key: const Key('ibscbs-values-pending')));
      }
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: tone ?? scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ibscbs.title'.tr(), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ...lines,
            ]),
          ),
        ]),
      ),
    );
  }
}
