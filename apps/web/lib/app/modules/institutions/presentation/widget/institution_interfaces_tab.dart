import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../data/datasource/institution_datasource.dart';
import '../../domain/entity/institution_interface_grant.dart';

/// Aba "Interfaces" do cadastro de Estabelecimento — CRUD do contrato
/// comercial (tb_institution_has_interface, decisões 17/18/23 da Fase 1):
/// o Super marca as interfaces que o cliente contratou.
///
/// Aba AUTÔNOMA (precedente dos checkboxes de privilégios da tela de
/// Interfaces): carrega e grava via datasource, fora do draft do bloc —
/// cada toggle sincroniza na hora (PUT com a lista completa; a API concede
/// a lista e revoga as demais com soft delete). Só funciona na EDIÇÃO:
/// o contrato vive no schema do cliente, que nasce no salvar do cadastro.
///
/// Filtros LOCAIS por módulo (group_default do catálogo) e nome da
/// interface (pedido do Valdo 2026-07-12 — catálogo chegará a ~300
/// interfaces): a lista completa já está em memória, filtrar não vai à API.
class InstitutionInterfacesTab extends StatefulWidget {
  const InstitutionInterfacesTab({
    required this.institutionId,
    required this.datasource,
    super.key,
  });

  /// null = inclusão (schema ainda não existe — aba orienta salvar antes).
  final int? institutionId;
  final InstitutionDatasource datasource;

  @override
  State<InstitutionInterfacesTab> createState() =>
      _InstitutionInterfacesTabState();
}

class _InstitutionInterfacesTabState extends State<InstitutionInterfacesTab> {
  List<InstitutionInterfaceGrant> _grants = [];
  bool _loading = false;
  bool _saving = false;

  /// Filtros locais: módulo (null = todos) e nome da interface.
  String? _moduleFilter;
  final _nameFilter = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.institutionId != null) _load();
  }

  @override
  void dispose() {
    _nameFilter.dispose();
    super.dispose();
  }

  /// Falhas SEMPRE via ponte (Framework de Mensagens, R1/R7) — a aba nunca
  /// chama ScaffoldMessenger/AlertDialog direto.
  void _fail(Failure failure) {
    if (!mounted) return;
    showFailureFeedback(context, failure);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final grants = await widget.datasource.getInterfaces(widget.institutionId!);
      if (mounted) setState(() => _grants = grants);
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Toggle = sincroniza o contrato na hora (PUT com a lista completa).
  /// Sucesso = SnackBar via ponte (R1); falhou → reverte o estado local e
  /// entrega o Failure à ponte.
  Future<void> _toggle(InstitutionInterfaceGrant grant, bool granted) async {
    final previous = _grants;
    final updated = [
      for (final g in _grants) g.id == grant.id ? g.copyWith(granted: granted) : g,
    ];
    setState(() {
      _grants = updated;
      _saving = true;
    });
    try {
      await widget.datasource.setInterfaces(
        widget.institutionId!,
        [for (final g in updated) if (g.granted) g.id],
      );
      if (mounted) {
        await showSuccessFeedback(context, 'forms.institution.interfacesSaved');
      }
    } on Failure catch (failure) {
      if (mounted) setState(() => _grants = previous);
      _fail(failure);
    } catch (_) {
      if (mounted) setState(() => _grants = previous);
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.institutionId == null) {
      // Inclusão: o schema do cliente ainda não existe (nasce no salvar).
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SetesText('forms.institution.interfacesSaveFirst'.tr()),
        ),
      );
    }
    if (_loading) return const SetesCircularProgressIndicator();
    if (_grants.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }

    // Domínio do filtro de módulo = grupos distintos do catálogo carregado.
    final modules = <String>{
      for (final grant in _grants) grant.groupDefault ?? '',
    }.toList()
      ..sort();

    // Filtros locais (módulo + nome) sobre a lista em memória.
    final nameQuery = _nameFilter.text.trim().toLowerCase();
    final visible = [
      for (final grant in _grants)
        if ((_moduleFilter == null ||
                (grant.groupDefault ?? '') == _moduleFilter) &&
            (nameQuery.isEmpty ||
                (grant.description ?? '').toLowerCase().contains(nameQuery)))
          grant,
    ];

    // Cabeçalho por agrupador do catálogo (a API já ordena por grupo/descrição).
    final children = <Widget>[];
    String? currentGroup;
    for (final grant in visible) {
      final group = grant.groupDefault ?? '';
      if (group != currentGroup) {
        currentGroup = group;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: SetesText(
            group.isEmpty
                ? 'forms.institution.interfacesNoGroup'.tr()
                : group,
          ),
        ));
      }
      children.add(SetesCheckbox(
        label: grant.description ?? '',
        value: grant.granted,
        enabled: !_saving,
        onChanged: (checked) => _toggle(grant, checked ?? false),
      ));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SetesDropdown<String?>(
                  label: 'forms.institution.interfacesFilterModule'.tr(),
                  value: _moduleFilter,
                  items: [null, ...modules],
                  itemLabel: (module) => module == null
                      ? 'forms.institution.interfacesAllModules'.tr()
                      : (module.isEmpty
                          ? 'forms.institution.interfacesNoGroup'.tr()
                          : module),
                  onChanged: (module) =>
                      setState(() => _moduleFilter = module),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SetesTextField(
                  label: 'register.filter'.tr(),
                  hint: 'forms.institution.interfacesFilterHint'.tr(),
                  controller: _nameFilter,
                  suffixIcon: Icons.search,
                  onChanged: (_) => setState(() {}), // filtro local, ao digitar
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: children.isEmpty
                ? Center(child: SetesText('register.emptyList'.tr()))
                : ListView(children: children),
          ),
        ],
      ),
    );
  }
}
