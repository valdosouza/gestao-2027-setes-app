import 'package:equatable/equatable.dart';

/// Entrada dos catálogos fiscais centrais (GET /api/tax-rules/catalogs):
/// CSTs, modalidades de base e desoneração. O id chega como string OU
/// número na API — aqui vira SEMPRE string (valor dos combos do form).
class CatalogEntry extends Equatable {
  const CatalogEntry({required this.id, this.description});

  final String id;
  final String? description;

  factory CatalogEntry.fromJson(Map<String, dynamic> json) => CatalogEntry(
        id:          '${json['id']}',
        description: json['description'] as String?,
      );

  /// Rótulo do combo: "código - descrição" (descrição vem do catálogo do
  /// banco — não se traduz, decisão 26).
  String get label =>
      (description ?? '').isEmpty ? id : '$id - $description';

  @override
  List<Object?> get props => [id, description];
}

/// Catálogos completos para os combos do form — carregados UMA vez na
/// abertura (lookup de apoio, exceção D6: sem paginação).
class TaxRuleCatalogs extends Equatable {
  const TaxRuleCatalogs({
    this.icmsNr = const [],
    this.icmsSn = const [],
    this.modBc = const [],
    this.modBcSt = const [],
    this.discharge = const [],
    this.ipi = const [],
    this.pis = const [],
    this.cofins = const [],
  });

  final List<CatalogEntry> icmsNr;
  final List<CatalogEntry> icmsSn;
  final List<CatalogEntry> modBc;
  final List<CatalogEntry> modBcSt;
  final List<CatalogEntry> discharge;
  final List<CatalogEntry> ipi;
  final List<CatalogEntry> pis;
  final List<CatalogEntry> cofins;

  static List<CatalogEntry> _list(dynamic value) =>
      (value as List<dynamic>? ?? const [])
          .map((e) => CatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList();

  factory TaxRuleCatalogs.fromJson(Map<String, dynamic> json) =>
      TaxRuleCatalogs(
        icmsNr:    _list(json['icmsNr']),
        icmsSn:    _list(json['icmsSn']),
        modBc:     _list(json['modBc']),
        modBcSt:   _list(json['modBcSt']),
        discharge: _list(json['discharge']),
        ipi:       _list(json['ipi']),
        pis:       _list(json['pis']),
        cofins:    _list(json['cofins']),
      );

  @override
  List<Object?> get props =>
      [icmsNr, icmsSn, modBc, modBcSt, discharge, ipi, pis, cofins];
}
