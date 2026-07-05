import 'package:equatable/equatable.dart';

/// Árvore de menus (decisão 21): módulos → interfaces → privilégios,
/// já filtrada pelo backend — o app só renderiza.
class MenuModule extends Equatable {
  const MenuModule({
    this.id,
    required this.description,
    this.icon,
    this.interfaces = const [],
  });

  /// null = pseudo-módulo vindo de tb_interface.group_default
  final int? id;
  final String description;
  final int? icon;
  final List<MenuInterface> interfaces;

  @override
  List<Object?> get props => [id, description, icon, interfaces];
}

class MenuInterface extends Equatable {
  const MenuInterface({
    required this.id,
    required this.description,
    this.buttonAction,
    this.imgIndex,
    this.privileges = const [],
  });

  final int id;
  final String description;
  final String? buttonAction;
  final int? imgIndex;

  /// Descrições de tb_privilege — alimentam os botões da UI (decisão 21).
  final List<String> privileges;

  bool can(String privilege) =>
      privileges.any((p) => p.toLowerCase() == privilege.toLowerCase());

  @override
  List<Object?> get props => [id, description, buttonAction, imgIndex, privileges];
}
