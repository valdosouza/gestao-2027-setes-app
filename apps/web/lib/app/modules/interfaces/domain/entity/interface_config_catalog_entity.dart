import 'package:equatable/equatable.dart';

/// Domínio de kind das configurações (decisão 6 do Framework de
/// Configurações) — espelho do DTO da API (interfaceConfigDto).
const List<String> kConfigKinds = [
  'String', 'Integer', 'Float', 'Boolean', 'Date', 'Options',
];

/// Linha do CATÁLOGO de configurações de uma interface
/// (setes_central.tb_interface_has_config — decisões 2 e 7): cadastrada
/// pelo Super na seção "Configurações" da tela de Interfaces.
class InterfaceConfigCatalogEntity extends Equatable {
  const InterfaceConfigCatalogEntity({
    required this.name,
    required this.description,
    required this.kind,
    required this.defaultContent,
    required this.scope,
    this.options,
  });

  factory InterfaceConfigCatalogEntity.fromJson(Map<String, dynamic> json) =>
      InterfaceConfigCatalogEntity(
        name:           json['name'] as String? ?? '',
        description:    json['description'] as String? ?? '',
        kind:           json['kind'] as String? ?? 'String',
        options:        json['options'] as String?,
        defaultContent: json['defaultContent'] as String? ?? '',
        scope:          json['scope'] as String? ?? 'I',
      );

  /// Chave da configuração (snake_case, ex-GRL_CAMPO).
  final String name;

  /// Descrição obrigatória — é o que salva o suporte (ex-GRL_DESCRICAO).
  final String description;

  /// String | Integer | Float | Boolean | Date | Options.
  final String kind;

  /// Lista fechada p/ kind Options: "A=Por item;B=Por total".
  final String? options;

  /// Padrão inicial do produto.
  final String defaultContent;

  /// 'I' = só institution; 'U' = admite override por usuário (decisão 4).
  final String scope;

  Map<String, dynamic> toJson() => {
        'description':    description,
        'kind':           kind,
        'options':        (options == null || options!.isEmpty) ? null : options,
        'defaultContent': defaultContent,
        'scope':          scope,
      };

  @override
  List<Object?> get props =>
      [name, description, kind, options, defaultContent, scope];
}
