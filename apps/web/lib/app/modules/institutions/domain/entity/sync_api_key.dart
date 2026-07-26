/// Chave de sincronização do estabelecimento (tb_sync_api_key na central —
/// D12 da revisão do sincronizador): UMA chave por estabelecimento, a MESMA
/// em todos os terminais dele; o Sincronizador a envia no header X-Api-Key
/// e a setes-sync resolve institution + schema por ela.
class SyncApiKey {
  const SyncApiKey({
    required this.apiKey,
    required this.establishmentCode,
    required this.active,
  });

  factory SyncApiKey.fromJson(Map<String, dynamic> json) => SyncApiKey(
        apiKey: json['apiKey'] as String? ?? '',
        establishmentCode: json['establishmentCode'] as String? ?? '',
        active: (json['active'] as String? ?? 'S') == 'S',
      );

  final String apiKey;
  final String establishmentCode;
  final bool active;
}
