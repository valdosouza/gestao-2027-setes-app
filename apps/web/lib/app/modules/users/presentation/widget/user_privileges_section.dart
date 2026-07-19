import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/users/datasource/user_datasource.dart';
import '../../../../shared/users/entity/user_entity.dart';

/// VISUALIZAR (tb_privilege id 6): decide o que entra no MENU do usuário
/// regular (opção 1 do workflow — espelho de @shared/auth/privileges da API).
const _visualizarId = 6;

/// Seção "Privilégios de Acesso" do cadastro de Usuário (workflow ACL do
/// Valdo, 2026-07-12) — modernização do modelo Delphi
/// (tas_user_has_privilege): as 3 partes viraram 2 níveis com filtro
/// (padrão validado na aba Interfaces do Estabelecimento):
///   filtro por módulo + nome → lista de interfaces CONTRATADAS →
///   toque abre os privilégios da interface (checkboxes) → PUT sincroniza.
///
/// O alvo é POR INSTITUTION (tb_user_has_privilege vive no schema do
/// cliente): super escolhe entre os estabelecimentos VINCULADOS do usuário;
/// admin do cliente é forçado ao institution do JWT (dropdown nem aparece).
/// Perfis admin/super nem precisam disto — a ACL vale para o REGULAR.
class UserPrivilegesSection extends StatefulWidget {
  const UserPrivilegesSection({
    required this.userId,
    required this.datasource,
    required this.isSuper,
    super.key,
  });

  final int userId;
  final UserDatasource datasource;
  final bool isSuper;

  @override
  State<UserPrivilegesSection> createState() => _UserPrivilegesSectionState();
}

class _UserPrivilegesSectionState extends State<UserPrivilegesSection> {
  List<UserInstitutionGrant> _institutions = [];
  int? _institutionId; // null p/ admin: a API resolve pelo JWT
  List<UserInterfacePrivileges> _items = [];
  bool _loading = false;
  bool _saving = false;

  String? _moduleFilter;
  final _nameFilter = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isSuper) {
      _loadInstitutions();
    } else {
      _loadPrivileges();
    }
  }

  @override
  void dispose() {
    _nameFilter.dispose();
    super.dispose();
  }

  /// Falha = dialog via PONTE de feedback (Framework de Mensagens) —
  /// a seção nunca chama ScaffoldMessenger/AlertDialog direto.
  void _fail(Failure failure) {
    if (!mounted) return;
    showFailureFeedback(context, failure);
  }

  /// Super: alvos possíveis = estabelecimentos VINCULADOS do usuário.
  Future<void> _loadInstitutions() async {
    setState(() => _loading = true);
    try {
      final grants = await widget.datasource.getInstitutions(widget.userId);
      final linked = [for (final g in grants) if (g.granted) g];
      if (mounted) {
        setState(() {
          _institutions = linked;
          _institutionId = linked.isNotEmpty ? linked.first.institutionId : null;
        });
        if (_institutionId != null) await _loadPrivileges();
      }
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPrivileges() async {
    setState(() => _loading = true);
    try {
      final items = await widget.datasource
          .getPrivileges(widget.userId, institutionId: _institutionId);
      if (mounted) setState(() => _items = items);
    } on Failure catch (failure) {
      if (mounted) setState(() => _items = []);
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editInterface(UserInterfacePrivileges item) async {
    final selected = await showDialog<List<int>>(
      context: context,
      builder: (_) => _PrivilegesDialog(item: item),
    );
    if (selected == null) return;
    setState(() => _saving = true);
    try {
      await widget.datasource.setPrivileges(
          widget.userId, item.interfaceId, selected,
          institutionId: _institutionId);
      if (mounted) {
        await showSuccessFeedback(context, 'forms.user.privilegesSaved');
        await _loadPrivileges();
      }
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Módulos da interface (filtro): tb_module do cliente, com fallback no
  /// group_default do catálogo (mesma lógica da aba Interfaces).
  List<String> _modulesOf(UserInterfacePrivileges item) {
    final names = item.moduleNames;
    if (names != null && names.isNotEmpty) return names.split(', ');
    return [item.groupDefault ?? ''];
  }

  @override
  Widget build(BuildContext context) {
    final moduleOptions = <String>{
      for (final item in _items) ..._modulesOf(item),
    }.toList()
      ..sort();

    final nameQuery = _nameFilter.text.trim().toLowerCase();
    final visible = [
      for (final item in _items)
        if ((_moduleFilter == null || _modulesOf(item).contains(_moduleFilter)) &&
            (nameQuery.isEmpty ||
                (item.description ?? '').toLowerCase().contains(nameQuery)))
          item,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SetesText('forms.user.privilegesTitle'.tr()),
        ),
        if (widget.isSuper) ...[
          if (_institutions.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SetesText('forms.user.privilegesLinkFirst'.tr()),
            )
          else
            SetesDropdown<int>(
              label: 'forms.user.privilegesInstitution'.tr(),
              value: _institutionId,
              items: [for (final i in _institutions) i.institutionId],
              itemLabel: (id) {
                final match =
                    _institutions.where((i) => i.institutionId == id);
                return match.isEmpty
                    ? '$id'
                    : '${match.first.name ?? ''} (${match.first.schemaName})';
              },
              onChanged: (id) {
                if (id == null) return;
                setState(() => _institutionId = id);
                _loadPrivileges();
              },
            ),
          const SizedBox(height: 8),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: SetesCircularProgressIndicator(),
          )
        else if (_items.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: SetesDropdown<String?>(
                  label: 'forms.institution.interfacesFilterModule'.tr(),
                  value: _moduleFilter,
                  items: [null, ...moduleOptions],
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
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in visible)
            SetesListTile(
              leading: Icon(item.privileges.any((p) => p.granted)
                  ? Icons.verified_user_outlined
                  : Icons.do_not_disturb_alt_outlined),
              title: SetesText(item.description ?? ''),
              subtitle: SetesText([
                _modulesOf(item)
                    .map((m) => m.isEmpty
                        ? 'forms.institution.interfacesNoGroup'.tr()
                        : m)
                    .join(', '),
                item.privileges.any((p) => p.granted)
                    ? item.privileges
                        .where((p) => p.granted)
                        .map((p) => p.description ?? '')
                        .join(' · ')
                    : 'forms.user.privilegesNone'.tr(),
              ].join(' — ')),
              onTap: _saving ? null : () => _editInterface(item),
            ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SetesText('register.emptyList'.tr()),
            ),
        ],
      ],
    );
  }
}

/// Dialog dos privilégios de UMA interface (3ª parte do modelo Delphi):
/// checkboxes do catálogo da interface. Marcar qualquer privilégio marca
/// VISUALIZAR junto — sem ele a interface some do menu do usuário regular.
class _PrivilegesDialog extends StatefulWidget {
  const _PrivilegesDialog({required this.item});

  final UserInterfacePrivileges item;

  @override
  State<_PrivilegesDialog> createState() => _PrivilegesDialogState();
}

class _PrivilegesDialogState extends State<_PrivilegesDialog> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final p in widget.item.privileges)
        if (p.granted) p.privilegeId,
    };
  }

  void _toggle(int privilegeId, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(privilegeId);
        // Operar exige enxergar: VISUALIZAR entra junto (menu — opção 1).
        _selected.add(_visualizarId);
      } else {
        _selected.remove(privilegeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText(widget.item.description ?? ''),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final privilege in widget.item.privileges)
                SetesCheckbox(
                  label: privilege.description ?? '',
                  value: _selected.contains(privilege.privilegeId),
                  onChanged: (checked) =>
                      _toggle(privilege.privilegeId, checked ?? false),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SetesText('forms.user.privilegesVisualizarHint'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'register.save'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () =>
                Navigator.of(context).pop(_selected.toList()..sort()),
          ),
        ],
      );
}
