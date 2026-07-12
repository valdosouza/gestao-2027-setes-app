import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/users/datasource/user_datasource.dart';
import '../../../../shared/users/entity/user_entity.dart';

/// Perfis aceitos em tb_institution_has_user.kind (vira o role do JWT).
/// 'super' só vale na institution 1 — fora dela o backend rebaixa p/ 'user'.
const _kinds = ['user', 'admin', 'super'];

/// Seção "Estabelecimentos" do cadastro de Usuário — CRUD dos vínculos
/// tb_institution_has_user (sem vínculo ativo o login devolve 403).
///
/// Seção AUTÔNOMA (precedente da aba Interfaces do Estabelecimento):
/// carrega e grava via datasource, fora do bloc — cada mudança (conceder,
/// revogar ou trocar o perfil) sincroniza na hora com rollback local no
/// erro. Renderizada via extraChildren da fábrica, SÓ na edição (o id do
/// usuário nasce no salvar).
class UserInstitutionsSection extends StatefulWidget {
  const UserInstitutionsSection({
    required this.userId,
    required this.datasource,
    super.key,
  });

  final int userId;
  final UserDatasource datasource;

  @override
  State<UserInstitutionsSection> createState() =>
      _UserInstitutionsSectionState();
}

class _UserInstitutionsSectionState extends State<UserInstitutionsSection> {
  List<UserInstitutionGrant> _grants = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final grants = await widget.datasource.getInstitutions(widget.userId);
      if (mounted) setState(() => _grants = grants);
    } on Failure catch (failure) {
      if (mounted) _snack(failure.message);
    } catch (_) {
      if (mounted) _snack('register.error'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync(List<UserInstitutionGrant> updated) async {
    final previous = _grants;
    setState(() {
      _grants = updated;
      _saving = true;
    });
    try {
      await widget.datasource.setInstitutions(widget.userId, [
        for (final g in updated)
          if (g.granted)
            (institutionId: g.institutionId, kind: g.kind ?? 'user'),
      ]);
      if (mounted) _snack('forms.user.institutionsSaved'.tr());
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _grants = previous);
        _snack(failure.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _grants = previous);
        _snack('register.error'.tr());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(UserInstitutionGrant grant, bool granted) => _sync([
        for (final g in _grants)
          g.institutionId == grant.institutionId
              ? g.copyWith(granted: granted, kind: g.kind ?? 'user')
              : g,
      ]);

  void _changeKind(UserInstitutionGrant grant, String kind) => _sync([
        for (final g in _grants)
          g.institutionId == grant.institutionId ? g.copyWith(kind: kind) : g,
      ]);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SetesCircularProgressIndicator(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SetesText('forms.user.institutions'.tr()),
        ),
        for (final grant in _grants)
          Row(
            children: [
              Expanded(
                child: SetesCheckbox(
                  label: '${grant.name ?? ''} (${grant.schemaName})',
                  value: grant.granted,
                  enabled: !_saving,
                  onChanged: (checked) => _toggle(grant, checked ?? false),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 160,
                child: SetesDropdown<String>(
                  label: 'forms.user.kind'.tr(),
                  value: _kinds.contains(grant.kind) ? grant.kind : 'user',
                  items: _kinds,
                  onChanged: grant.granted && !_saving
                      ? (kind) {
                          if (kind != null) _changeKind(grant, kind);
                        }
                      : (_) {},
                ),
              ),
            ],
          ),
      ],
    );
  }
}
