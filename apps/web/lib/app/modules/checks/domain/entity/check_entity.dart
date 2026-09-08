import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo checks — Cheques (tela de PROCESSO, grupo
/// Financeiro; prompt_cheque_rastreabilidade.md D1–D10 + D7a–c). Cheque =
/// título ao PORTADOR que substitui a dívida do cliente na baixa do
/// faturamento; cabeçalho (tb_check) é IMUTÁVEL e o estado é SEMPRE
/// DERIVADO do último evento (tb_check_event, append-only) no servidor.
/// Espelho do /api/checks; datas em ISO 'yyyy-MM-dd'.
///
/// O evento 'R' (recebido) NÃO tem endpoint nesta tela — nasce só na
/// transação da baixa do faturamento; a partir daí o cheque é PORTADO por
/// aqui através dos demais eventos.

/// Estados derivados do cheque (query `?status=` e campo `state`).
abstract final class CheckStatus {
  static const custody = 'custody';
  static const bank = 'bank';
  static const factoring = 'factoring';
  static const supplier = 'supplier';
  static const refunded = 'refunded';
  static const collection = 'collection';

  static const all = [custody, bank, factoring, supplier, refunded, collection];
}

/// Kinds dos eventos: R recebido · B depositado · D descontado ·
/// P usado em pagamento · T retorno com reembolso · F retorno bom ·
/// V devolvido (sem fundos) · X estornado.
abstract final class CheckEventKind {
  static const received = 'R';
  static const bank = 'B';
  static const discounted = 'D';
  static const paid = 'P';
  static const refundReturn = 'T';
  static const goodReturn = 'F';
  static const returned = 'V';
  static const reversed = 'X';
}

/// Kind do cabeçalho: P próprio (do pagador) · T de terceiro.
abstract final class CheckHeaderKind {
  static const own = 'P';
  static const third = 'T';
}

/// Linha da lista (GET /api/checks) — cabeçalho resumido + estado.
class CheckListRow extends Equatable {
  const CheckListRow({
    required this.id,
    this.bankLabel,
    this.agency = '',
    this.account = '',
    this.number = '',
    this.issuer = '',
    this.value = 0,
    this.dtCheck = '',
    this.headerKind = CheckHeaderKind.own,
    this.state = CheckStatus.custody,
    this.entityName,
  });

  final int     id;
  final String? bankLabel;
  final String  agency;
  final String  account;
  final String  number;
  final String  issuer;
  final double  value;
  final String  dtCheck;

  /// 'P' | 'T' (ver [CheckHeaderKind]).
  final String  headerKind;

  /// 'custody' | 'bank' | 'factoring' | 'supplier' | 'refunded' | 'collection'.
  final String  state;

  /// Quem entregou o cheque (evento R) — null se não resolvido.
  final String? entityName;

  bool get isCustody => state == CheckStatus.custody;
  bool get isBank => state == CheckStatus.bank;
  bool get isFactoring => state == CheckStatus.factoring;
  bool get isSupplier => state == CheckStatus.supplier;
  bool get isRefunded => state == CheckStatus.refunded;
  bool get isCollection => state == CheckStatus.collection;

  factory CheckListRow.fromJson(Map<String, dynamic> json) => CheckListRow(
        id:         jsonInt(json['id']) ?? 0,
        bankLabel:  json['bankLabel'] as String?,
        agency:     json['agency']?.toString() ?? '',
        account:    json['account']?.toString() ?? '',
        number:     json['number']?.toString() ?? '',
        issuer:     json['issuer']?.toString() ?? '',
        value:      jsonDouble(json['value']) ?? 0,
        dtCheck:    json['dtCheck'] as String? ?? '',
        headerKind: json['headerKind'] as String? ?? CheckHeaderKind.own,
        state:      json['state'] as String? ?? CheckStatus.custody,
        entityName: json['entityName'] as String?,
      );

  @override
  List<Object?> get props => [
        id, bankLabel, agency, account, number, issuer, value, dtCheck,
        headerKind, state, entityName,
      ];
}

/// Evento da história do cheque (tb_check_event, append-only).
class CheckEventRow extends Equatable {
  const CheckEventRow({
    required this.event,
    required this.kind,
    this.dtRecord = '',
    this.entityId,
    this.entityName,
    this.settledCode,
    this.orderId,
    this.parcel,
    this.bankAccountId,
    this.originEvent,
    this.note,
    this.userId,
  });

  final int     event;

  /// R | B | D | P | T | F | V | X (ver [CheckEventKind]).
  final String  kind;
  final String  dtRecord;
  final int?    entityId;
  final String? entityName;
  final int?    settledCode;
  final int?    orderId;
  final int?    parcel;
  final int?    bankAccountId;

  /// Evento invertido pelo estorno ('X').
  final int?    originEvent;
  final String? note;
  final int?    userId;

  factory CheckEventRow.fromJson(Map<String, dynamic> json) => CheckEventRow(
        event:         jsonInt(json['event']) ?? 0,
        kind:          json['kind'] as String? ?? '',
        dtRecord:      json['dtRecord'] as String? ?? '',
        entityId:      jsonInt(json['entityId']),
        entityName:    json['entityName'] as String?,
        settledCode:   jsonInt(json['settledCode']),
        orderId:       jsonInt(json['orderId']),
        parcel:        jsonInt(json['parcel']),
        bankAccountId: jsonInt(json['bankAccountId']),
        originEvent:   jsonInt(json['originEvent']),
        note:          json['note'] as String?,
        userId:        jsonInt(json['userId']),
      );

  @override
  List<Object?> get props => [
        event, kind, dtRecord, entityId, entityName, settledCode, orderId,
        parcel, bankAccountId, originEvent, note, userId,
      ];
}

/// Detalhe do cheque (GET /api/checks/:id) — cabeçalho + história completa.
class CheckFull extends CheckListRow {
  const CheckFull({
    required super.id,
    super.bankLabel,
    super.agency,
    super.account,
    super.number,
    super.issuer,
    super.value,
    super.dtCheck,
    super.headerKind,
    super.state,
    super.entityName,
    this.events = const [],
  });

  final List<CheckEventRow> events;

  /// Nº do evento MAIS RECENTE — só ele pode ser estornado (D10); null se
  /// não houver histórico (nunca deveria acontecer, sempre há ao menos o R).
  int? get lastEvent => events.isEmpty ? null : events.last.event;

  factory CheckFull.fromJson(Map<String, dynamic> json) {
    final row = CheckListRow.fromJson(json);
    return CheckFull(
      id:         row.id,
      bankLabel:  row.bankLabel,
      agency:     row.agency,
      account:    row.account,
      number:     row.number,
      issuer:     row.issuer,
      value:      row.value,
      dtCheck:    row.dtCheck,
      headerKind: row.headerKind,
      state:      row.state,
      entityName: row.entityName,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => CheckEventRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [...super.props, events];
}

/// Lookup do catálogo CENTRAL de bancos (GET /api/checks/banks) — não é
/// consumido por nenhum dialog desta onda (o cabeçalho é imutável, criado
/// pela baixa do faturamento); existe para paridade com a API/uso futuro.
class CheckBankLookup extends Equatable {
  const CheckBankLookup({required this.id, this.number = '', this.description});

  final int     id;
  final String  number;
  final String? description;

  String get display => [
        if (number.isNotEmpty) number,
        if (description != null && description!.isNotEmpty) description!,
      ].join(' - ');

  factory CheckBankLookup.fromJson(Map<String, dynamic> json) => CheckBankLookup(
        id:          jsonInt(json['id']) ?? 0,
        number:      json['number']?.toString() ?? '',
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, number, description];
}

/// Conta corrente da institution (GET /api/checks/bank-accounts) — a opção
/// "Caixa" (id 0) NÃO vem da API: é oferecida pela TELA, fixa na frente da
/// lista, nos dialogs cujo DTO aceita bankAccountId 0 (molde settlements).
class CheckBankAccountLookup extends Equatable {
  const CheckBankAccountLookup({required this.id, this.label = ''});

  final int    id;
  final String label;

  factory CheckBankAccountLookup.fromJson(Map<String, dynamic> json) =>
      CheckBankAccountLookup(
        id:    jsonInt(json['id']) ?? 0,
        label: json['label']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [id, label];
}

/// Fornecedor (GET /api/checks/providers) — a factoring costuma ser um
/// provider cadastrado (Q3 do parecer conceitual).
class CheckProviderLookup extends Equatable {
  const CheckProviderLookup({required this.id, this.name = ''});

  final int    id;
  final String name;

  factory CheckProviderLookup.fromJson(Map<String, dynamic> json) =>
      CheckProviderLookup(
        id:   jsonInt(json['id']) ?? 0,
        name: json['name']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [id, name];
}

/// Título a PAGAR aberto (GET /api/checks/open-payables) — candidato ao
/// "usar em pagamento" (evento P).
class CheckOpenPayable extends Equatable {
  const CheckOpenPayable({
    required this.orderId,
    required this.parcel,
    this.number,
    this.entityName,
    this.dtExpiration,
    this.balance = 0,
  });

  final int     orderId;
  final int     parcel;
  final String? number;
  final String? entityName;
  final String? dtExpiration;
  final double  balance;

  /// Identidade na seleção (PK lógica orderId+parcel).
  String get key => '$orderId-$parcel';

  factory CheckOpenPayable.fromJson(Map<String, dynamic> json) => CheckOpenPayable(
        orderId:      jsonInt(json['orderId']) ?? 0,
        parcel:       jsonInt(json['parcel']) ?? 0,
        number:       json['number'] as String?,
        entityName:   json['entityName'] as String?,
        dtExpiration: json['dtExpiration'] as String?,
        balance:      jsonDouble(json['balance']) ?? 0,
      );

  @override
  List<Object?> get props =>
      [orderId, parcel, number, entityName, dtExpiration, balance];
}

/// Resultado das ações que geram 1 baixa (evento + settled_code): depositar
/// (B), descontar (D), retorno com reembolso (T) e usar em pagamento (P).
class CheckSettledResult extends Equatable {
  const CheckSettledResult({this.event = 0, this.settledCode = 0});

  final int event;
  final int settledCode;

  factory CheckSettledResult.fromJson(Map<String, dynamic> json) =>
      CheckSettledResult(
        event:       jsonInt(json['event']) ?? 0,
        settledCode: jsonInt(json['settledCode']) ?? 0,
      );

  @override
  List<Object?> get props => [event, settledCode];
}

/// Resultado da devolução (evento V) — [orderId] é o título NOVO criado
/// contra o cliente de origem.
class CheckReturnResult extends Equatable {
  const CheckReturnResult({this.event = 0, this.orderId = 0});

  final int event;
  final int orderId;

  factory CheckReturnResult.fromJson(Map<String, dynamic> json) =>
      CheckReturnResult(
        event:   jsonInt(json['event']) ?? 0,
        orderId: jsonInt(json['orderId']) ?? 0,
      );

  @override
  List<Object?> get props => [event, orderId];
}

/// Resultado do estorno (evento X) — [affectedCheckIds] inclui os DEMAIS
/// cheques do mesmo settled_code quando o evento estornado é 'R' ou 'P'
/// (D9 do prompt).
class CheckReverseResult extends Equatable {
  const CheckReverseResult({this.event = 0, this.affectedCheckIds = const []});

  final int event;
  final List<int> affectedCheckIds;

  factory CheckReverseResult.fromJson(Map<String, dynamic> json) =>
      CheckReverseResult(
        event: jsonInt(json['event']) ?? 0,
        affectedCheckIds: (json['affectedCheckIds'] as List<dynamic>? ?? [])
            .map((e) => jsonInt(e) ?? 0)
            .toList(),
      );

  @override
  List<Object?> get props => [event, affectedCheckIds];
}
