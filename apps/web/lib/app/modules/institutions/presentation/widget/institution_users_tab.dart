import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
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

  /// Falhas SEMPRE via ponte (Framework de Mensagens, R1/R7) — a aba nunca
  /// chama ScaffoldMessenger/AlertDialog direto.
  void _fail(Failure failure) {
    if (!mounted) return;
    showFailureFeedback(context, failure);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await widget.datasource
          .getList('', institutionId: widget.institutionId);
      if (mounted) setState(() => _users = users);
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
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
    if (saved == true && mounted) {
      await showSuccessFeedback(context, 'register.saved');
      await _load();
    }
  }

  /// Clique na linha: edição básica (nome/apelido/email/senha/ativo/perfil).
  Future<void> _editUser(UserListItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserDialog(
        institutionId: widget.institutionId!,
        datasource: widget.datasource,
        editingId: item.id,
        initialKind: item.kind,
      ),
    );
    if (saved == true && mounted) {
      await showSuccessFeedback(context, 'register.saved');
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
                    // Perfil do vínculo com ESTE institution (kind)
                    '${'forms.user.kind'.tr()}: ${user.kind ?? '-'}',
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
/// transação); edição carrega o completo, faz PUT (senha vazia mantém) e,
/// se o PERFIL mudou, sincroniza o vínculo deste institution (a aba é do
/// Super — setInstitutions preserva os demais vínculos do usuário).
/// Perfil 'super' não é editável aqui (exclusivo da tela de Usuários).
class _UserDialog extends StatefulWidget {
  const _UserDialog({
    required this.institutionId,
    required this.datasource,
    this.editingId,
    this.initialKind,
  });

  final int institutionId;
  final UserDatasource datasource;
  final int? editingId;

  /// Perfil atual do vínculo (edição) — null na inclusão.
  final String? initialKind;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _name  = TextEditingController();
  final _nick  = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nameFocus = FocusNode();
  final _nickFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameKey = GlobalKey<FormFieldState<String>>();
  final _nickKey = GlobalKey<FormFieldState<String>>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _passwordKey = GlobalKey<FormFieldState<String>>();
  late String _kind;
  bool _active = true;
  bool _loading = false;
  bool _saving = false;

  bool get _creating => widget.editingId == null;

  /// 'super' não se edita pela aba — dropdown escondido nesse caso.
  bool get _kindEditable => _creating || _kinds.contains(widget.initialKind);

  @override
  void initState() {
    super.initState();
    // Inclusão: objetivo da aba é liberar o primeiro admin do cliente.
    _kind = _creating ? 'admin' : (widget.initialKind ?? 'user');
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
    } on Failure catch (failure) {
      if (mounted) {
        await showFailureFeedback(context, failure);
        if (mounted) Navigator.of(context).pop(false);
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
    for (final node in [_nameFocus, _nickFocus, _emailFocus, _passwordFocus]) {
      node.dispose();
    }
    super.dispose();
  }

  /// Campos NA ORDEM da tela (R3) — uma pendência por vez via ponte:
  /// dialog → foco/marca SÓ no campo apontado; nunca o dialog inteiro
  /// vermelho.
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'name',
          focusNode: _nameFocus,
          fieldKey: _nameKey,
          validate: () => _tr(SetesValidators.required())(_name.text),
        ),
        PendencyField(
          name: 'nick',
          focusNode: _nickFocus,
          fieldKey: _nickKey,
          validate: () => _tr(SetesValidators.required())(_nick.text),
        ),
        PendencyField(
          name: 'email',
          focusNode: _emailFocus,
          fieldKey: _emailKey,
          validate: () => _tr(SetesValidators.compose([
            SetesValidators.required(),
            SetesValidators.email(),
          ]))(_email.text),
        ),
        PendencyField(
          name: 'password',
          focusNode: _passwordFocus,
          fieldKey: _passwordKey,
          validate: () => _tr(_creating
              ? SetesValidators.compose([
                  SetesValidators.required(),
                  SetesValidators.minLength(5),
                ])
              : SetesValidators.minLength(5))(_password.text),
        ),
      ];

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    if (!mounted) return;
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
        // Perfil mudou → sincroniza SÓ o vínculo deste institution,
        // preservando os demais (a aba é do Super — endpoint de vínculos).
        if (_kindEditable && _kind != widget.initialKind) {
          final grants =
              await widget.datasource.getInstitutions(widget.editingId!);
          await widget.datasource.setInstitutions(widget.editingId!, [
            for (final g in grants)
              if (g.granted)
                (
                  institutionId: g.institutionId,
                  kind: g.institutionId == widget.institutionId
                      ? _kind
                      : (g.kind ?? 'user'),
                ),
          ]);
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _saving = false);
        // Falha via ponte, ancorando o fields[] do servidor no campo do
        // dialog quando a API apontar (ex.: e-mail já cadastrado).
        await showServerFieldFeedback(context, failure, _pendencyFields);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        await showFailureFeedback(
            context, const Failure(message: 'register.error'));
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
                  // Scroll: garante o campo Perfil visível em janela baixa.
                  child: SingleChildScrollView(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SetesTextField(
                        label: 'forms.user.name'.tr(),
                        controller: _name,
                        focusNode: _nameFocus,
                        fieldKey: _nameKey,
                        autofocus: true,
                        validator: _tr(SetesValidators.required()),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.user.nick'.tr(),
                        controller: _nick,
                        focusNode: _nickFocus,
                        fieldKey: _nickKey,
                        validator: _tr(SetesValidators.required()),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.user.email'.tr(),
                        controller: _email,
                        focusNode: _emailFocus,
                        fieldKey: _emailKey,
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
                        focusNode: _passwordFocus,
                        fieldKey: _passwordKey,
                        obscureText: true,
                        validator: _tr(_creating
                            ? SetesValidators.compose([
                                SetesValidators.required(),
                                SetesValidators.minLength(5),
                              ])
                            : SetesValidators.minLength(5)),
                      ),
                      const SizedBox(height: 8),
                      // Perfil do vínculo com ESTE institution: editável na
                      // inclusão E na edição; 'super' fica de fora da aba
                      // (exclusivo da tela de Usuários do módulo Super).
                      if (_kindEditable)
                        SetesDropdown<String>(
                          label: 'forms.user.kind'.tr(),
                          value: _kinds.contains(_kind) ? _kind : 'user',
                          items: _kinds,
                          onChanged: (kind) =>
                              setState(() => _kind = kind ?? 'admin'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: SetesText(
                              '${'forms.user.kind'.tr()}: ${widget.initialKind ?? '-'}'),
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
