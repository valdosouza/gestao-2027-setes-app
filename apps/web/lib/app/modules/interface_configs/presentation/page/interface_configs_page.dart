import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/interface_config/entity/interface_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../../../../shared/register/register_search_page.dart';
import '../bloc/interface_configs_bloc.dart';

/// Painel de configurações do sistema — interface 'interface-configs'
/// (Framework de Configurações, decisões 7, 9 e 11).
///
/// Vitrine: TODAS as interfaces do produto (molde do interface_fields);
/// as adquiridas abrem a lista de configurações, montada 100% a partir do
/// CATÁLOGO — nenhuma tela artesanal por opção. Renderização por kind
/// (decisão 6): Boolean = switch, Options = dropdown, Date = datepicker,
/// demais = dialog com validação do kind.
///
/// Perfis (decisão 4): admin edita o VALOR DA INSTITUTION; usuário comum
/// edita apenas o PRÓPRIO override das configs scope 'U'.
class InterfaceConfigsPage extends StatefulWidget {
  const InterfaceConfigsPage({
    required this.title,
    this.initialModuleKey,
    this.returnRoute,
    super.key,
  });

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  /// Atalho da engrenagem (decisão 11): abre já filtrado neste módulo.
  final String? initialModuleKey;

  /// Rota da tela que chamou a engrenagem — o voltar retorna para ELA
  /// (sem arguments: o módulo chamador recai no título trCatalog padrão).
  /// null = entrada pelo menu, voltar mostra a vitrine.
  final String? returnRoute;

  @override
  State<InterfaceConfigsPage> createState() => _InterfaceConfigsPageState();
}

class _InterfaceConfigsPageState extends State<InterfaceConfigsPage> {
  late final InterfaceConfigsBloc _bloc;

  /// Perfil do usuário logado (via /api/core/me): decide o alvo do salvar
  /// (institution × override pessoal) e o que fica editável.
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<InterfaceConfigsBloc>();
    final moduleKey = widget.initialModuleKey;
    if (moduleKey != null && moduleKey.isNotEmpty) {
      _bloc.add(InterfaceConfigsOpenByKey(moduleKey));
    } else {
      _bloc.add(const InterfaceConfigsVitrineRequested(''));
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await Modular.get<GetMeUsecase>()();
    result.fold(
      (_) {},
      (me) {
        if (mounted) setState(() => _isAdmin = me.isAdmin);
      },
    );
  }

  void _openInterface(InterfaceVitrineEntity iface) {
    if (!iface.acquired) {
      // Bloqueio corrigível pelo usuário → dialog de validação via ponte.
      showValidationFeedback(
          context, 'forms.interfaceConfigs.notAcquired'.tr());
      return;
    }
    _bloc.add(InterfaceConfigsInterfaceOpened(iface));
  }

  bool _canEdit(InterfaceConfigEntity config) =>
      _isAdmin || config.allowsUserOverride;

  void _save(String name, String? content) =>
      _bloc.add(InterfaceConfigsValueSaveRequested(
        name: name,
        content: content,
        asUser: !_isAdmin,
      ));

  // -------------------------------------------------------------------
  // Renderização por kind (decisão 6)
  // -------------------------------------------------------------------

  /// Origem do valor efetivo — mostra ao suporte/usuário de onde ele vem.
  String _originLabel(InterfaceConfigEntity config) {
    if (config.userContent != null) {
      return 'forms.interfaceConfigs.originUser'.tr();
    }
    if (config.institutionContent != null) {
      return 'forms.interfaceConfigs.originInstitution'.tr();
    }
    return 'forms.interfaceConfigs.originDefault'.tr();
  }

  Widget _buildConfigTile(InterfaceConfigEntity config) {
    // O rótulo é a DESCRIÇÃO do catálogo — o nome técnico (snake_case) não
    // aparece para o cliente (pedido do Valdo, 2026-07-18); ele segue
    // visível só no cadastro do catálogo (tela de Interfaces, Super).
    final subtitle = _originLabel(config);
    final enabled = _canEdit(config);

    switch (config.kind) {
      case 'Boolean':
        return SetesSwitch(
          label: config.description,
          subtitle: subtitle,
          value: config.boolValue,
          enabled: enabled,
          onChanged: (checked) => _save(config.name, checked ? 'S' : 'N'),
        );
      case 'Options':
        final options = config.optionsList;
        InterfaceConfigOption? selected;
        for (final option in options) {
          if (option.value == config.content) selected = option;
        }
        return SetesListTile(
          leading: const Icon(Icons.tune),
          title: SetesText(config.description),
          subtitle: SetesText(subtitle),
          trailing: SizedBox(
            width: 220,
            child: IgnorePointer(
              ignoring: !enabled,
              child: SetesDropdown<InterfaceConfigOption>(
                label: '',
                items: options,
                value: selected,
                itemLabel: (option) => option.label,
                onChanged: (option) {
                  if (option != null) _save(config.name, option.value);
                },
              ),
            ),
          ),
        );
      case 'Date':
        return SetesListTile(
          leading: const Icon(Icons.event_outlined),
          title: SetesText(config.description),
          subtitle: SetesText('$subtitle\n${config.content}'),
          onTap: enabled ? () => _pickDate(config) : null,
        );
      default: // String | Integer | Float
        return SetesListTile(
          leading: Icon(enabled ? Icons.edit_outlined : Icons.lock_outline),
          title: SetesText(config.description),
          subtitle: SetesText('$subtitle\n${config.content}'),
          onTap: enabled ? () => _editValueDialog(config) : null,
        );
    }
  }

  Future<void> _pickDate(InterfaceConfigEntity config) async {
    final current = DateTime.tryParse(config.content) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      _save(config.name, formatted);
    }
  }

  Future<void> _editValueDialog(InterfaceConfigEntity config) async {
    final result = await showDialog<_ValueDialogResult>(
      context: context,
      builder: (_) => _ConfigValueDialog(config: config),
    );
    if (result != null) _save(config.name, result.content);
  }

  // -------------------------------------------------------------------
  // Telas
  // -------------------------------------------------------------------

  Widget _buildVitrine(InterfaceConfigsVitrineState state) =>
      RegisterSearchPage<InterfaceVitrineEntity>(
        title: widget.title,
        items: state.items,
        loading: state.loading,
        avatarBuilder: (i) => '${i.id}',
        rowBuilder: (i) => [
          i.description ?? '',
          if ((i.moduleNames ?? '').isNotEmpty) i.moduleNames!,
          i.acquired
              ? 'forms.interfaceConfigs.acquired'.tr()
              : 'forms.interfaceConfigs.available'.tr(),
        ],
        onFilterChanged: (filter) =>
            _bloc.add(InterfaceConfigsVitrineRequested(filter)),
        onView: _openInterface,
      );

  /// Voltar: chegada pela engrenagem retorna à tela CHAMADORA (fix
  /// 2026-07-18 — antes caía na vitrine do painel); pelo menu, vitrine.
  void _goBack() {
    final route = widget.returnRoute;
    if (route != null && route.isNotEmpty) {
      Modular.to.navigate(route);
    } else {
      _bloc.add(const InterfaceConfigsBackToVitrine());
    }
  }

  Widget _buildConfigs(InterfaceConfigsConfigsState state) => SetesFormShell(
        title: '${widget.title} · ${state.iface.description ?? ''}',
        saving: state.saving,
        onBack: _goBack,
        child: state.loading
            ? const SetesCircularProgressIndicator()
            : state.configs.isEmpty
                ? Center(
                    child:
                        SetesText('forms.interfaceConfigs.emptyCatalog'.tr()))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.configs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _buildConfigTile(state.configs[index]),
                  ),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<InterfaceConfigsBloc, InterfaceConfigsState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is InterfaceConfigsActionSuccess ||
            current is InterfaceConfigsActionFailure,
        // PONTE de feedback (Framework de Mensagens): sucesso = SnackBar
        // via ponte (R1); falha = dialog — a ponte deriva a natureza (R7).
        listener: (context, state) {
          if (state is InterfaceConfigsActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          showFailureFeedback(
              context, (state as InterfaceConfigsActionFailure).failure);
        },
        buildWhen: (_, current) =>
            current is InterfaceConfigsVitrineState ||
            current is InterfaceConfigsConfigsState,
        builder: (context, state) => switch (state) {
          InterfaceConfigsConfigsState() => _buildConfigs(state),
          InterfaceConfigsVitrineState() => _buildVitrine(state),
          _ => _buildVitrine(const InterfaceConfigsVitrineState(loading: true)),
        },
      );
}

class _ValueDialogResult {
  const _ValueDialogResult(this.content);

  /// null = restaurar o herdado (institution → default).
  final String? content;
}

/// Dialog de edição de valor para kinds String/Integer/Float — validação
/// local do kind; "Restaurar padrão" envia content null (volta a herdar).
class _ConfigValueDialog extends StatefulWidget {
  const _ConfigValueDialog({required this.config});

  final InterfaceConfigEntity config;

  @override
  State<_ConfigValueDialog> createState() => _ConfigValueDialogState();
}

class _ConfigValueDialogState extends State<_ConfigValueDialog> {
  late final TextEditingController _value;
  final _valueFocus = FocusNode();
  final _valueKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: widget.config.content);
  }

  @override
  void dispose() {
    _value.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  bool _isValid(String content) => switch (widget.config.kind) {
        'Integer' => RegExp(r'^-?\d+$').hasMatch(content),
        'Float' => RegExp(r'^-?\d+([.,]\d+)?$').hasMatch(content),
        _ => content.length <= 100,
      };

  /// Validação do kind (mesma regra do validator inline do campo).
  String? _validateValue() {
    final content = _value.text.trim();
    return (content.isEmpty || !_isValid(content))
        ? 'forms.interfaceConfigs.invalidValue'.tr()
        : null;
  }

  /// UMA pendência por vez (R3): dialog da ponte → OK → foco no campo.
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'content',
          validate: _validateValue,
          focusNode: _valueFocus,
          fieldKey: _valueKey,
        ),
      ];

  Future<void> _submit() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    if (!mounted) return;
    Navigator.of(context).pop(_ValueDialogResult(_value.text.trim()));
  }

  /// Restaurar o herdado é uma DECISÃO (R4): Sim = limpar o valor próprio
  /// (volta a herdar institution → default); Cancelar = nada.
  Future<void> _confirmRestore() async {
    final decision = await askDecision(
      context,
      message: 'forms.interfaceConfigs.restoreConfirm'.tr(),
    );
    if (decision != SetesDecision.yes || !mounted) return;
    Navigator.of(context).pop(const _ValueDialogResult(null));
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final numeric = config.kind == 'Integer' || config.kind == 'Float';
    return AlertDialog(
      // Descrição como título — o nome técnico não aparece para o cliente.
      title: SetesText(config.description),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesTextField(
              label: 'forms.interfaceConfigs.value'.tr(),
              controller: _value,
              autofocus: true,
              focusNode: _valueFocus,
              fieldKey: _valueKey,
              keyboardType: numeric ? TextInputType.number : null,
              inputFormatters: config.kind == 'Integer'
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))]
                  : null,
              // marca SÓ este campo após o OK do dialog de pendência (R3)
              validator: (_) => _validateValue(),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            SetesText(
                '${'forms.interfaceConfigs.defaultValue'.tr()}: ${config.defaultContent}'),
          ],
        ),
      ),
      actions: [
        SetesButton(
          label: 'forms.interfaceConfigs.restoreDefault'.tr(),
          kind: SetesButtonKind.text,
          onPressed: _confirmRestore,
        ),
        SetesButton(
          label: 'register.cancel'.tr(),
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SetesButton(
          label: 'register.save'.tr(),
          kind: SetesButtonKind.text,
          onPressed: _submit,
        ),
      ],
    );
  }
}
