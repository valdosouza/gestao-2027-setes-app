import 'package:core/core.dart';
/// Linha da vitrine de interfaces do painel Sistema/Admin (decisão 6 da
/// Fase 2): TODAS as interfaces do produto, marcando as adquiridas —
/// estratégia comercial para instigar o cliente a contratar outras.
class InterfaceVitrineEntity {
  const InterfaceVitrineEntity({
    required this.id,
    this.description,
    this.i18nKey,
    this.acquired = false,
    this.moduleNames,
  });

  factory InterfaceVitrineEntity.fromJson(Map<String, dynamic> json) =>
      InterfaceVitrineEntity(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String?,
        i18nKey:     json['i18nKey'] as String?,
        acquired:    json['acquired'] == 'S',
        moduleNames: json['moduleNames'] as String?,
      );

  final int id;
  final String? description;
  final String? i18nKey;

  /// Nome da interface como aparece no MENU (traduzido pelo catálogo i18n,
  /// `menu.interfaces.<i18nKey>`); sem tradução, cai na descrição técnica.
  /// Achado do passeio logado de 2026-09-30: os painéis de configurações e de
  /// campos exibiam a descrição em inglês ("My Establishment").
  String get displayName =>
      trCatalog(i18nKey, description ?? '', prefix: 'menu.interfaces');

  /// true = interface no contrato comercial (tb_institution_has_interface).
  final bool acquired;

  /// Módulos do cliente que contêm a interface (filtro do painel).
  final String? moduleNames;
}
