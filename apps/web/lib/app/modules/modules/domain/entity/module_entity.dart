import 'package:equatable/equatable.dart';

/// Módulo de Menu do cliente (tb_module + tb_module_has_interface no schema
/// do cliente) — interface 'modules', camada 2 do menu
/// (prompt_modulo_menus.md D1–D4, Valdo 2026-08-04). Espelho da API:
/// setes-api/src/modules/modules/modules.interface.ts (ModuleRow).
class ModuleEntity extends Equatable {
  const ModuleEntity({
    required this.id,
    this.description,
    this.position,
    this.imageIcon,
    this.interfaceIds = const [],
  });

  /// Código gerado pelo backend (MAX+1 — precedente do cadastro de
  /// Privilégios). 0 = ainda não gerado (inclusão).
  final int id;
  final String? description;

  /// Posição no menu; null = fim da fila (a API resolve MAX+1).
  final int? position;

  /// NOME de ícone Material (D4 — string, ex.: 'shopping_cart'); null = padrão.
  final String? imageIcon;

  /// Ids das interfaces vinculadas, NA ORDEM do menu (D3 — a ordem do array
  /// É a ordem das telas).
  final List<int> interfaceIds;

  factory ModuleEntity.fromJson(Map<String, dynamic> json) => ModuleEntity(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String?,
        position:    (json['position'] as num?)?.toInt(),
        imageIcon:   json['imageIcon'] as String?,
        interfaceIds: [
          for (final id in json['interfaceIds'] as List<dynamic>? ?? [])
            (id as num).toInt(),
        ],
      );

  @override
  List<Object?> get props => [id, description, position, imageIcon, interfaceIds];
}

/// Interface ELEGÍVEL ao vínculo (GET /api/modules/interface-lookup —
/// contratada, kind 'T', fora do Super). Alimenta o picker e os rótulos da
/// seção "Telas do módulo".
class ModuleInterfaceOption extends Equatable {
  const ModuleInterfaceOption({
    required this.id,
    this.description,
    this.i18nKey,
    this.groupDefault,
  });

  final int id;
  final String? description;

  /// Chave de tradução do catálogo (rótulo via `menu.interfaces.<i18nKey>`,
  /// fallback na description — decisão 26).
  final String? i18nKey;
  final String? groupDefault;

  factory ModuleInterfaceOption.fromJson(Map<String, dynamic> json) =>
      ModuleInterfaceOption(
        id:           (json['id'] as num).toInt(),
        description:  json['description'] as String?,
        i18nKey:      json['i18nKey'] as String?,
        groupDefault: json['groupDefault'] as String?,
      );

  @override
  List<Object?> get props => [id, description, i18nKey, groupDefault];
}
