import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/users/datasource/user_datasource.dart';
import '../../../../shared/users/entity/user_entity.dart';

/// Perfis oferecidos na criação pelo Super via aba (workflow 2026-07-12:
/// o objetivo é liberar o PRIMEIRO admin do cliente). 'super' fica fora —
/// é exclusivo da institution 1 e gerenciado pela tela de Usuários.
const _kinds = ['admin', 'user'];

/// Aba "Usuários" do cadastro de Estabelecimento (workflow do Valdo
/// 2026-07-12): com muitos institutions, selecionar o certo pela tela de
/// Usuários é difícil — aqui o sistema JÁ SABE o institution: a lista vem
/// filtrada e o botão + chama o cadastro de usuário com o vínculo
/// implícito (POST com institutionId+kind, criado na mesma transação).
///
/// Aba AUTÔNOMA (padrão da aba Interfaces): shared/users datasource, fora
/// do draft do bloc. Só na edição (o institution precisa existir).
class InstitutionUsersTab extends StatefulWidget {
  const InstitutionUsersTab({
    required this.institutionId,
    required this.datasource,
    super.key,
  });

  /// null = inclusão (aba orienta salvar o estabelecimento primeiro).
  final int? institutionId;
  final UserDatasource datasource;

  @override
  State<InstitutionUsersTab> createState() => _InstitutionUsersTabState();
}

class _InstitutionUsersTabState extends State<InstitutionUsersTab> {
  List<UserListItem> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.institutionId != null) _load();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await widget.datasource
          .getList('', institutionId: widget.institutionId);
      if (mounted) setState(() => _users = users);
    } on Failure catch (failure) {
      if (mounted) _snack(failure.message);
    } catch (_) {
      if (mounted) _snack('register.error'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Botão + : cadastro de usuário com o institution IMPLÍCITO.
  Future<void> _addUser() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserDialog(
        institutionId: widget.institutionId!,
        datasource: widget.datasource,
      ),
    );
    if (saved == true) {
      _snack('register.saved'.tr());
      await _load();
    }
  }

  /// Clique na linha: edição básica (nome/apelido/email/senha/ativo).
  Future<void> _editUser(UserListItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserDialog(
        institutionId: widget.institutionId!,
        datasource: widget.datasource,
        editingId: item.id,
      ),
    );
    if (saved == true) {
      _snack('register.saved'.tr());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.institutionId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SetesText('forms.institution.usersSaveFirst'.tr()),
        ),
      );
    }
    if (_loading) return const SetesCircularProgressIndicator();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'institution_user_add',
        onPressed: _addUser,
        child: const Icon(Icons.add),
      ),
      body: _users.isEmpty
          ? Center(child: SetesText('register.emptyList'.tr()))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _users[index];
                return SetesListTile(
                  leading: CircleAvatar(child: SetesText('${user.id}')),
                  title: SetesText(user.name ?? ''),
                  subtitle: SetesText([
                    user.email ?? '',
                    user.active
                        ? 'forms.institution.active'.tr()
                        : 'forms.institution.inactive'.tr(),
                  ].join(' · ')),
                  onTap: () => _editUser(user),
                );
              },
            ),
    );
  }
}

/// Dialog do cadastro de usuário chamado pela aba — o institution já é
/// conhecido: inclusão faz POST com institutionId+kind (vínculo na mesma
/// transação); edição carrega o completo e faz PUT (senha vazia mantém).
class _UserDialog extends StatefulWidget {
  const _UserDialog({
    required this.institutionId,
    required this.datasource,
    this.editingId,
  });

  final int institutionId;
  final UserDatasource datasource;
  final int? editingId;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name  = TextEditingController();
  final _nick  = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _kind = 'admin'; // objetivo da aba: liberar o primeiro admin
  bool _active = true;
  bool _loading = false;
  bool _saving = false;

  bool get _creating => widget.editingId == null;

  @override
  void initState() {
    super.initState();
    if (!_creating) _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final user = await widget.datasource.get(widget.editingId!);
      if (mounted) {
        setState(() {
          _name.text  = user.nameCompany;
          _nick.text  = user.nickTrade;
          _email.text = user.email;
          _active     = user.active;
        });
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nick.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = UserEntity(
        id:          widget.editingId,
        nameCompany: _name.text.trim(),
        nickTrade:   _nick.text.trim(),
        email:       _email.text.trim(),
        password:    _password.text.isEmpty ? null : _password.text,
        active:      _active,
      );
      if (_creating) {
        await widget.datasource.post(user,
            institutionId: widget.institutionId, kind: _kind);
      } else {
        await widget.datasource.put(user);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: SetesText(failure.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: SetesText('register.error'.tr())));
      }
    }
  }

  String? Function(String?) _tr(String? Function(String?) validator) =>
      (value) => validator(value)?.tr();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.institution.userDialogTitle'.tr()),
        content: SizedBox(
          width: 460,
          child: _loading
              ? const SetesCircularProgressIndicator()
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SetesTextField(
                        label: 'forms.user.name'.tr(),
                        controller: _name,
                        autofocus: true,
                        validator: _tr(SetesValidators.required()),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.user.nick'.tr(),
                        controller: _nick,
                        validator: _tr(SetesValidators.required()),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.user.email'.tr(),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: _tr(SetesValidators.compose([
                          SetesValidators.required(),
                          SetesValidators.email(),
                        ])),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.user.password'.tr(),
                        hint: _creating
                            ? null
                            : 'forms.user.passwordKeepHint'.tr(),
                        controller: _password,
                        obscureText: true,
                        validator: _tr(_creating
                            ? SetesValidators.compose([
                                SetesValidators.required(),
                                SetesValidators.minLength(5),
                              ])
                            : SetesValidators.minLength(5)),
                      ),
                      const SizedBox(height: 8),
                      if (_creating)
                        SetesDropdown<String>(
                          label: 'forms.user.kind'.tr(),
                          value: _kind,
                          items: _kinds,
                          onChanged: (kind) =>
                              setState(() => _kind = kind ?? 'admin'),
                        ),
                      SetesCheckbox(
                        label: 'forms.user.active'.tr(),
                        value: _active,
                        onChanged: (checked) =>
                            setState(() => _active = checked ?? true),
                      ),
                    ],
                  ),
                ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _saving ? () {} : () => Navigator.of(context).pop(false),
          ),
          SetesButton(
            label: 'register.save'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _saving ? () {} : _save,
          ),
        ],
      );
}
