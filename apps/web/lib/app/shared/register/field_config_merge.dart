import 'package:easy_localization/easy_localization.dart';
import 'package:setes_validators/setes_validators.dart';

import '../field_config/entity/field_config_entity.dart';
import 'register_form_page.dart';

/// ENGINE de merge dos campos configuráveis (decisão 7 da Fase 2):
/// custom do cliente → catálogo → código. O código continua dono de ordem,
/// lookups, teclado e abas; a config sobrepõe caption/required/mask.
///
/// Uso na página (com o mixin FieldConfigLoader):
/// `fields: applyFieldConfig([...campos declarados...], fieldConfig)`.
List<RegisterField> applyFieldConfig(
    List<RegisterField> fields, List<FieldConfigEntity> config) {
  if (config.isEmpty) return fields;
  final byName = {for (final c in config) c.fieldNameCamel: c};
  return [for (final field in fields) _merge(field, byName[field.name])];
}

RegisterField _merge(RegisterField field, FieldConfigEntity? config) {
  if (config == null) return field;

  if (field.isLookup) {
    // FK: config aplica caption e obrigatoriedade (validatorMessage do
    // código tem precedência — o cliente só aperta, decisão 2).
    return RegisterField.lookup(
      name:    field.name,
      label:   config.caption ?? field.label,
      display: field.display,
      onPick:  field.onPick,
      validatorMessage: field.validatorMessage ??
          (config.required ? 'forms.validation.required'.tr() : null),
    );
  }

  // Obrigatoriedade apertada pelo cliente entra ANTES do validator do código
  // (que segue valendo — baseline técnico nunca afrouxa, decisão 2).
  final validators = <SetesValidator>[
    if (config.required && !field.readOnly) SetesValidators.required(),
    if (config.mask != null) SetesValidators.mask(config.mask!),
    if (field.validator != null) field.validator!,
  ];

  return RegisterField(
    name:         field.name,
    label:        config.caption ?? field.label,
    obscure:      field.obscure,
    readOnly:     field.readOnly,
    keyboardType: field.keyboardType,
    mask:         config.mask ?? field.mask,
    validator:
        validators.isEmpty ? null : SetesValidators.compose(validators),
  );
}
