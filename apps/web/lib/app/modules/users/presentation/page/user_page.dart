import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/register/field_config_merge.dart';
import '../../../../shared/register/register_form_page.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/users/datasource/user_datasource.dart';
import '../../../../shared/users/entity/user_entity.dart';
import '../bloc/user_bloc.dart';
import '../widget/user_institutions_section.dart';

/// Tela de Usuários — interface 'users' (1 interface = 1 módulo,
/// ARQUITETURA_MODULOS.md). Grava a cadeia do LOGIN (análise do módulo
/// auth 2026-07-12): tb_entity + tb_user (senha MD5 no backend) +
/// tb_mailing grupo 2 (email de login).
///
/// INDEPENDENTE de contexto (workflow do Valdo 2026-07-12): serve o SUPER
/// (módulo Super — seção Estabelecimentos gerencia vínculos de qualquer
/// institution) e o ADMIN do cliente (módulo Sistema — o institution é
/// implícito: a API força o vínculo/escopo pela institution do JWT, então
/// a seção de Estabelecimentos nem aparece).
///
/// Código gerado pelo backend (MAX+1 da tb_entity — herança por PK):
/// readOnly sempre. Senha: obrigatória na inclusão; na edição vazia =
/// mantém a atual.
class UserPage extends StatefulWidget {
  const UserPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> with FieldConfigLoader {
  late final UserBloc _bloc;
  late final UserDatasource _datasource;

  /// Ativo (tb_user.active) — estado da página, fora dos values da fábrica.
  bool _active = true;
  int? _editingId;

  /// Super enxerga a seção Estabelecimentos; admin do cliente NÃO (o
  /// institution é implícito — API força o escopo do JWT).
  bool _isSuper = false;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<UserBloc>()..add(const UserListRequested(''));
    _datasource = Modular.get<UserDatasource>();
    loadFieldConfig('users'); // engine de campos configuráveis (decisão 7)
    _loadRole();
  }

  Future<void> _loadRole() async {
    final result = await Modular.get<GetMeUsecase>()();
    result.fold(
      (_) {}, // sem sessão legível → mantém o modo restrito (admin)
      (me) {
        if (mounted && me.role == 'super' && me.institutionId == 1) {
          setState(() => _isSuper = true);
        }
      },
    );
  }

  Widget _buildForm(UserFormState state) {
    final editing = state.editing;
    final creating = editing == null;
    // Sincroniza o estado local ao trocar de registro.
    if (_editingId != editing?.id) {
      _editingId = editing?.id;
      _active = editing?.active ?? true;
    }
    return RegisterFormPage(
      key: ValueKey(creating ? 'user-new' : 'user-${editing.id}'),
      title: widget.title,
      saving: state.saving,
      initialValues: creating
          ? const {}
          : {
              'id':          '${editing.id}',
              'nameCompany': editing.nameCompany,
              'nickTrade':   editing.nickTrade,
              'email':       editing.email,
            },
      fields: applyFieldConfig([
        // Código gerado pelo backend (MAX+1 da tb_entity): sempre readOnly.
        RegisterField(
          name:     'id',
          label:    'forms.user.code'.tr(),
          readOnly: true,
        ),
        RegisterField(
          name:      'nameCompany',
          label:     'forms.user.name'.tr(),
          validator: SetesValidators.required(),
        ),
        RegisterField(
          name:      'nickTrade',
          label:     'forms.user.nick'.tr(),
          validator: SetesValidators.required(),
        ),
        RegisterField(
          name:         'email',
          label:        'forms.user.email'.tr(),
          keyboardType: TextInputType.emailAddress,
          validator: SetesValidators.compose([
            SetesValidators.required(),
            SetesValidators.email(),
          ]),
        ),
        RegisterField(
          name:    'password',
          label:   'forms.user.password'.tr(),
          obscure: true,
          // Inclusão: obrigatória. Edição: vazia mantém a atual.
          validator: creating
              ? SetesValidators.compose([
                  SetesValidators.required(),
                  SetesValidators.minLength(5),
                ])
              : SetesValidators.minLength(5),
        ),
      ], fieldConfig),
      extraChildren: [
        SetesCheckbox(
          label: 'forms.user.active'.tr(),
          value: _active,
          onChanged: (checked) => setState(() => _active = checked ?? true),
        ),
        // Vínculos multi-institution: exclusivos do SUPER. Para o admin do
        // cliente o institution é implícito (workflow 2026-07-12): o POST
        // já vincula à institution logada — nada a mostrar.
        if (_isSuper)
          if (creating)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SetesText('forms.user.institutionsSaveFirst'.tr()),
            )
          else
            UserInstitutionsSection(
              userId: editing.id!,
              datasource: _datasource,
            ),
      ],
      onSave: (values) => _bloc.add(UserSaveRequested(
        user: UserEntity(
          id:          creating ? null : editing.id,
          nameCompany: values['nameCompany'] ?? '',
          nickTrade:   values['nickTrade'] ?? '',
          email:       values['email'] ?? '',
          password: (values['password'] ?? '').isEmpty
              ? null
              : values['password'],
          active: _active,
        ),
        creating: creating,
      )),
      onCancel: () => _bloc.add(const UserBackToListPressed()),
      onDelete: creating
          ? null
          : () => _bloc.add(UserDeleteRequested(editing.id!)),
      canDelete: !creating,
    );
  }

  Widget _buildSearch(UserListState state) => RegisterSearchPage<UserListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        items: state.items,
        loading: state.loading,
        avatarBuilder: (u) => '${u.id}',
        rowBuilder: (u) => [
          u.name ?? '',
          u.email ?? '',
          u.active
              ? 'forms.institution.active'.tr()
              : 'forms.institution.inactive'.tr(),
        ],
        onFilterChanged: (filter) => _bloc.add(UserListRequested(filter)),
        onNew: () => _bloc.add(const UserNewPressed()),
        onView: (u) => _bloc.add(UserEditPressed(u.id)),
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<UserBloc, UserState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is UserActionSuccess || current is UserActionFailure,
        listener: (context, state) {
          final message = state is UserActionSuccess
              ? state.messageKey.tr()
              : (state as UserActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is UserListState || current is UserFormState,
        builder: (context, state) => switch (state) {
          UserFormState() => _buildForm(state),
          UserListState() => _buildSearch(state),
          _ => _buildSearch(const UserListState(loading: true)),
        },
      );
}
