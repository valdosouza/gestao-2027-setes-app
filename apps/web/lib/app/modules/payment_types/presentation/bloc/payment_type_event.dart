part of 'payment_type_bloc.dart';

sealed class PaymentTypeEvent extends Equatable {
  const PaymentTypeEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). O filtro
/// por descrição é REMOTO (?filter= — D7). Paginação D3: [page] navega
/// (filtro novo SEMPRE volta à página 1 na tela); [pageSize] null mantém
/// o tamanho corrente (1º load = config page_size da API — D4).
class PaymentTypeListRequested extends PaymentTypeEvent {
  const PaymentTypeListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class PaymentTypeNewPressed extends PaymentTypeEvent {
  const PaymentTypeNewPressed();
}

class PaymentTypeEditPressed extends PaymentTypeEvent {
  const PaymentTypeEditPressed(this.paymentType);
  final LinkedPaymentType paymentType;

  @override
  List<Object?> get props => [paymentType];
}

/// Volta do formulário para a lista SEM salvar.
class PaymentTypeBackToListPressed extends PaymentTypeEvent {
  const PaymentTypeBackToListPressed();
}

/// Salvar: [editingId] null = novo vínculo (via [catalogId] OU
/// [description]/[idNfce] — criar/reusar); preenchido = atualizar o
/// vínculo. [attrs] = configuração operacional do vínculo (migration 012).
class PaymentTypeSaveRequested extends PaymentTypeEvent {
  const PaymentTypeSaveRequested({
    this.editingId,
    this.catalogId,
    this.description,
    this.idNfce,
    required this.attrs,
  });

  final int? editingId;
  final int? catalogId;
  final String? description;
  final String? idNfce;
  final PaymentTypeLinkAttrs attrs;

  @override
  List<Object?> get props => [editingId, catalogId, description, idNfce, attrs];
}

/// Desvincula a forma (o catálogo permanece).
class PaymentTypeDeleteRequested extends PaymentTypeEvent {
  const PaymentTypeDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
