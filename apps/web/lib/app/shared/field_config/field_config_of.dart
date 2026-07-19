import 'entity/field_config_entity.dart';

/// Config resolvida de UM campo para formulários HÍBRIDOS (fora da fábrica
/// RegisterFormPage — o merge da fábrica é o applyFieldConfig de
/// shared/register/field_config_merge.dart). A página aplica manualmente:
/// caption no label, required na cadeia de pendências (R3) e mask no
/// formatter + unmask no payload (decisões 7/16/19 da Fase 2).
///
/// Busca por nome da coluna (snake_case, como no catálogo
/// tb_interface_has_field) ou pelo camelCase do payload.
FieldConfigEntity? fieldConfigOf(
    List<FieldConfigEntity> config, String fieldName) {
  for (final c in config) {
    if (c.fieldName == fieldName || c.fieldNameCamel == fieldName) return c;
  }
  return null;
}
