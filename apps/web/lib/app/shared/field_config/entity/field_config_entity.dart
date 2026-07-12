/// Config RESOLVIDA de um campo (Fase 2 campos configuráveis, decisão 7):
/// merge cliente → catálogo feito pela API (GET /api/interface-fields/key/*).
/// requiredTech='S' = baseline técnico travado; required = efetivo.
class FieldConfigEntity {
  const FieldConfigEntity({
    required this.fieldName,
    required this.kind,
    required this.requiredTech,
    required this.required,
    this.caption,
    this.mask,
    this.customized = false,
  });

  factory FieldConfigEntity.fromJson(Map<String, dynamic> json) =>
      FieldConfigEntity(
        fieldName:    json['fieldName'] as String? ?? '',
        kind:         json['kind'] as String? ?? 'String',
        requiredTech: json['requiredTech'] == 'S',
        required:     json['required'] == 'S',
        caption:      json['caption'] as String?,
        mask:         json['mask'] as String?,
        customized:   json['customized'] == 'S',
      );

  /// Nome da coluna conforme a tabela (snake_case — como no catálogo).
  final String fieldName;

  /// String | Integer | Float | Boolean | Date.
  final String kind;

  /// Baseline técnico ('S' no catálogo): travado no painel do cliente.
  final bool requiredTech;

  /// Obrigatoriedade EFETIVA (técnica OU apertada pelo cliente).
  final bool required;

  /// Caption custom do cliente (null = i18n padrão do app).
  final String? caption;

  /// Máscara custom (`#` = dígito, `A` = letra, demais literais — decisão 16).
  final String? mask;

  /// true = existe especialização do cliente para este campo.
  final bool customized;

  /// fieldName em camelCase — casa com RegisterField.name e o payload JSON.
  String get fieldNameCamel => fieldName.replaceAllMapped(
      RegExp(r'_([a-z0-9])'), (m) => m.group(1)!.toUpperCase());
}
