import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo price_lists — Tabelas de Preço (D7 do
/// prompt_modulo_services.md, 2026-09-01). Espelho do /api/price-lists:
/// tb_price_list no schema do cliente (PK id + institution, MAX+1).
/// Consumida pela grade de preços do cadastro de serviço (tb_price) e,
/// no futuro, pelo cadastro de produtos — telas irmãs (D6).

/// Linha da lista E da edição (a tabela não tem campos além dos da lista —
/// o GET /:id devolve o mesmo shape).
class PriceListEntity extends Equatable {
  const PriceListEntity({
    required this.id,
    required this.description,
    this.validity,
    this.modality,
    this.published = 'S',
  });

  final int    id;
  final String description;

  /// Vigência ISO 'yyyy-MM-dd' (null = sem prazo).
  final String? validity;

  /// Modalidade (char livre — sem catálogo na web ainda).
  final String? modality;

  /// 'S' = publicada (default), 'N' = não publicada.
  final String published;

  factory PriceListEntity.fromJson(Map<String, dynamic> json) =>
      PriceListEntity(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String? ?? '',
        validity:    json['validity'] as String?,
        modality:    json['modality'] as String?,
        published:   json['published'] as String? ?? 'S',
      );

  @override
  List<Object?> get props => [id, description, validity, modality, published];
}

/// Body do POST/PUT — mesmo shape do priceListDto da API (Zod:
/// description máx 45, modality 1 char, validity 'yyyy-MM-dd' ou null).
class PriceListInput extends Equatable {
  const PriceListInput({
    required this.description,
    this.validity,
    this.modality,
    this.published = 'S',
  });

  final String  description;
  final String? validity;
  final String? modality;
  final String  published;

  Map<String, dynamic> toJson() => {
        'description': description,
        'validity':    validity,
        'modality':    modality,
        'published':   published,
      };

  @override
  List<Object?> get props => [description, validity, modality, published];
}
