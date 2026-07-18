import 'package:equatable/equatable.dart';

/// Item de lookup de PAPEL da cadeia de entidade fiscal (salesman, carrier,
/// ... — Fase 3 Entidade Única, decisão 11): versão MÍNIMA para listas de
/// apoio (FK). O nome vem de setes_central.tb_entity via JOIN da API.
///
/// Vive em app/shared/lookup (padrão campo-lookup-fk.md): os CADASTROS de
/// Vendedor/Transportadora ficam para a onda 2 — o lookup já nasce aqui
/// porque servirá aos módulos deles também.
class RoleLookup extends Equatable {
  const RoleLookup({required this.id, this.name});

  final int     id;
  final String? name;

  factory RoleLookup.fromJson(Map<String, dynamic> json) => RoleLookup(
        id:   (json['id'] as num).toInt(),
        name: json['name'] as String?,
      );

  @override
  List<Object?> get props => [id, name];
}
