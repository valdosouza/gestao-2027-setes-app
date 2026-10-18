import 'institution_interface_grant.dart';

/// Fonte do vínculo estabelecimento × interfaces (`tb_institution_has_interface`
/// — quais telas cada cliente tem) para a [InstitutionInterfacesTab].
///
/// Dois consumidores desde a D-PV11 (Valdo 2026-10-18 —
/// `prompt_privilegios_interfaces.md`), cada um com o datasource do PRÓPRIO
/// módulo (módulo nunca chama o /api de outro): a aba Interfaces do cadastro
/// de Estabelecimento (Super — `/api/admin/institutions/:id/interfaces`) e a
/// tela "Interfaces dos clientes" (delegável pelo Super a usuário da Setes —
/// `/api/institution-interfaces/:id`).
abstract class InstitutionInterfacesSource {
  Future<List<InstitutionInterfaceGrant>> getInterfaces(int institutionId);
  Future<void> setInterfaces(int institutionId, List<int> interfaceIds);
}
