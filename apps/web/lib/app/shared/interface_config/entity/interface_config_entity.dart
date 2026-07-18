/// Configuração RESOLVIDA de uma interface (Framework de Configurações,
/// decisão 4): merge usuário → institution → default feito pela API
/// (GET /api/interface-configs/key/* e /api/interface-configs/:id).
class InterfaceConfigEntity {
  const InterfaceConfigEntity({
    required this.name,
    required this.description,
    required this.kind,
    required this.defaultContent,
    required this.scope,
    required this.content,
    this.options,
    this.institutionContent,
    this.userContent,
  });

  factory InterfaceConfigEntity.fromJson(Map<String, dynamic> json) =>
      InterfaceConfigEntity(
        name:               json['name'] as String? ?? '',
        description:        json['description'] as String? ?? '',
        kind:               json['kind'] as String? ?? 'String',
        options:            json['options'] as String?,
        defaultContent:     json['defaultContent'] as String? ?? '',
        scope:              json['scope'] as String? ?? 'I',
        institutionContent: json['institutionContent'] as String?,
        userContent:        json['userContent'] as String?,
        content:            json['content'] as String? ?? '',
      );

  /// Chave da configuração (snake_case — ex-GRL_CAMPO).
  final String name;

  /// Descrição do catálogo — é o que salva o suporte (ex-GRL_DESCRICAO).
  final String description;

  /// String | Integer | Float | Boolean | Date | Options (decisão 6).
  final String kind;

  /// Lista fechada p/ kind Options: "A=Por item;B=Por total".
  final String? options;

  /// Padrão inicial do produto (catálogo central).
  final String defaultContent;

  /// 'I' = só institution; 'U' = admite override por usuário (decisão 4).
  final String scope;

  /// Valor da institution (null = segue o default).
  final String? institutionContent;

  /// Override do usuário corrente (null = sem override).
  final String? userContent;

  /// Valor EFETIVO para o usuário corrente (usuário → institution → default).
  final String content;

  bool get allowsUserOverride => scope == 'U';

  /// Atalho para kind Boolean ('S'/'N').
  bool get boolValue => content == 'S';

  /// Opções separadas do kind Options ("A=Por item" → value/label).
  List<InterfaceConfigOption> get optionsList {
    final raw = options;
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) {
      final eq = part.indexOf('=');
      if (eq < 0) return InterfaceConfigOption(value: part, label: part);
      return InterfaceConfigOption(
        value: part.substring(0, eq).trim(),
        label: part.substring(eq + 1).trim(),
      );
    }).toList();
  }
}

class InterfaceConfigOption {
  const InterfaceConfigOption({required this.value, required this.label});

  final String value;
  final String label;
}
