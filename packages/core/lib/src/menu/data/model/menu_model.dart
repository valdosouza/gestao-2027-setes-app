import '../../domain/entity/menu_entity.dart';

/// Model do GET /api/core/menus:
/// `{ ok, data: [{ module: {id, description, icon}, interfaces: [...] }] }`
class MenuModuleModel extends MenuModule {
  const MenuModuleModel({
    super.id,
    required super.description,
    super.icon,
    super.interfaces,
  });

  factory MenuModuleModel.fromJson(Map<String, dynamic> json) {
    final module = json['module'] as Map<String, dynamic>? ?? {};
    final interfaces = (json['interfaces'] as List<dynamic>? ?? [])
        .map((e) => MenuInterfaceModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return MenuModuleModel(
      id: (module['id'] as num?)?.toInt(),
      description: module['description'] as String? ?? 'Geral',
      icon: (module['icon'] as num?)?.toInt(),
      interfaces: interfaces,
    );
  }

  static MenuModuleModel empty() => const MenuModuleModel(description: 'Geral');
}

class MenuInterfaceModel extends MenuInterface {
  const MenuInterfaceModel({
    required super.id,
    required super.description,
    super.i18nKey,
    super.buttonAction,
    super.imgIndex,
    super.privileges,
  });

  factory MenuInterfaceModel.fromJson(Map<String, dynamic> json) =>
      MenuInterfaceModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        description: json['description'] as String? ?? '',
        i18nKey: json['i18nKey'] as String?,
        buttonAction: json['buttonAction'] as String?,
        imgIndex: (json['imgIndex'] as num?)?.toInt(),
        privileges: (json['privileges'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
