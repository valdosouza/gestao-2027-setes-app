import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../data/datasource/interface_datasource.dart';
import '../../domain/entity/interface_config_catalog_entity.dart';

/// Seção "Configurações" da tela de Interfaces (Framework de Configurações,
/// decisões 6 e 7): CRUD do CATÁLOGO tb_interface_has_config, no padrão da
/// aba autônoma (precedente institution_interfaces_tab) — carrega no init e
/// grava cada operação na hora (PUT/DELETE), fora do draft do form.
/// Só opera com a interface JÁ SALVA; na inclusão orienta salvar primeiro
/// (precedente da aba Permissões do cadastro de Usuário).
class InterfaceConfigsSection extends StatefulWidget {
  const InterfaceConfigsSection({
    required this.interfaceId,
    required this.datasource,
    super.key,
  });

  /// null = interface ainda não salva (modo inclusão).
  final int? interfaceId;
  final InterfaceDatasource datasource;

  @override
  State<InterfaceConfigsSection> createState() =>
      _InterfaceConfigsSectionState();
}

class _InterfaceConfigsSectionState extends State<InterfaceConfigsSection> {
  List<InterfaceConfigCatalogEntity> _configs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final id = widget.interfaceId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final configs = await widget.datasource.getConfigs(id);
      if (mounted) setState(() => _configs = configs);
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Falha = dialog via PONTE de feedback (Framework de Mensagens) —
  /// a seção nunca chama ScaffoldMessenger/AlertDialog direto.
  void _fail(Failure failure) {
    if (!mounted) return;
    showFailureFeedback(context, failure);
  }

  Future<void> _edit([InterfaceConfigCatalogEntity? config]) async {
    final result = await showDialog<InterfaceConfigCatalogEntity>(
      context: context,
      builder: (_) => _ConfigCatalogDialog(config: config),
    );
    if (result == null) return;
    try {
      await widget.datasource.saveConfig(widget.interfaceId!, result);
      if (mounted) {
        await showSuccessFeedback(context, 'forms.interface.configSaved');
      }
      await _reload();
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    }
  }

  Future<void> _delete(InterfaceConfigCatalogEntity config) async {
    // Decisão TIPADA da ponte (R4): Sim = excluir; Cancelar = nada.
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision != SetesDecision.yes) return;
    try {
      await widget.datasource.deleteConfig(widget.interfaceId!, config.name);
      if (mounted) {
        await showSuccessFeedback(context, 'forms.interface.configDeleted');
      }
      await _reload();
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: SetesText(
              'forms.interface.configs'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (widget.interfaceId != null)
            SetesIconButton(
              icon: Icons.add,
              tooltip: 'forms.interface.configAdd'.tr(),
              onPressed: () => _edit(),
            ),
        ],
      ),
      const SizedBox(height: 8),
    ];

    if (widget.interfaceId == null) {
      children.add(SetesText('forms.interface.configsSaveFirst'.tr()));
    } else if (_loading) {
      children.add(const SetesCircularProgressIndicator());
    } else if (_configs.isEmpty) {
      children.add(SetesText('forms.interface.configsEmpty'.tr()));
    } else {
      children.addAll([
        for (final config in _configs)
          SetesListTile(
            leading: const Icon(Icons.settings_outlined),
            title: SetesText(config.name),
            subtitle: SetesText([
              config.description,
              config.kind,
              '${'forms.interface.configDefault'.tr()}: ${config.defaultContent}',
              config.scope == 'U'
                  ? 'forms.interface.configScopeUser'.tr()
                  : 'forms.interface.configScopeInstitution'.tr(),
            ].join(' · ')),
            trailing: SetesIconButton(
              icon: Icons.delete_outline,
              tooltip: 'register.delete'.tr(),
              onPressed: () => _delete(config),
            ),
            onTap: () => _edit(config),
          ),
      ]);
    }

    return ExcludeFocusTraversal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Dialog de cadastro/edição de UMA configuração do catálogo — nome travado
/// na edição (é a PK junto com a interface); Options exige a lista fechada.
class _ConfigCatalogDialog extends StatefulWidget {
  const _ConfigCatalogDialog({this.config});

  final InterfaceConfigCatalogEntity? config;

  @override
  State<_ConfigCatalogDialog> createState() => _ConfigCatalogDialogState();
}

class _ConfigCatalogDialogState extends State<_ConfigCatalogDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _options;
  late final TextEditingController _defaultContent;
  late String _kind;
  late bool _scopeUser;

  bool get _editing => widget.config != null;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _name           = TextEditingController(text: config?.name ?? '');
    _description    = TextEditingController(text: config?.description ?? '');
    _options        = TextEditingController(text: config?.options ?? '');
    _defaultContent = TextEditingController(text: config?.defaultContent ?? '');
    _kind           = config?.kind ?? 'String';
    _scopeUser      = config?.scope == 'U';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _options.dispose();
    _defaultContent.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _name.text.trim();
    if (!RegExp(r'^[a-z][a-z0-9_]{0,49}$').hasMatch(name)) {
      return 'forms.interface.configNameInvalid'.tr();
    }
    if (_description.text.trim().isEmpty) {
      return 'forms.interface.configDescriptionRequired'.tr();
    }
    final defaultContent = _defaultContent.text.trim();
    if (defaultContent.isEmpty) {
      return 'forms.interface.configDefaultRequired'.tr();
    }
    if (_kind == 'Options') {
      final options = _options.text.trim();
      if (options.isEmpty) return 'forms.interface.configOptionsRequired'.tr();
      final values = options
          .split(';')
          .map((part) => part.split('=').first.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (!values.contains(defaultContent)) {
        return 'forms.interface.configDefaultNotInOptions'.tr();
      }
    }
    if (_kind == 'Boolean' &&
        defaultContent != 'S' && defaultContent != 'N') {
      return 'forms.interface.configBooleanDefault'.tr();
    }
    return null;
  }

  /// UMA pendência por vez (R3): a primeira falha do [_validate] vira
  /// dialog da ponte e o cadastro segue aberto para correção.
  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      await showValidationFeedback(context, error);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(InterfaceConfigCatalogEntity(
      name:           _name.text.trim(),
      description:    _description.text.trim(),
      kind:           _kind,
      options:        _kind == 'Options' ? _options.text.trim() : null,
      defaultContent: _defaultContent.text.trim(),
      scope:          _scopeUser ? 'U' : 'I',
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText(_editing
            ? widget.config!.name
            : 'forms.interface.configAdd'.tr()),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SetesTextField(
                  label: 'forms.interface.configName'.tr(),
                  hint: 'forms.interface.configNameHint'.tr(),
                  controller: _name,
                  readOnly: _editing, // PK do catálogo — não muda
                  autofocus: !_editing,
                ),
                const SizedBox(height: 16),
                SetesTextField(
                  label: 'forms.interface.configDescription'.tr(),
                  hint: 'forms.interface.configDescriptionHint'.tr(),
                  controller: _description,
                ),
                const SizedBox(height: 16),
                SetesDropdown<String>(
                  label: 'forms.interface.configKind'.tr(),
                  items: kConfigKinds,
                  value: _kind,
                  onChanged: (kind) =>
                      setState(() => _kind = kind ?? 'String'),
                ),
                if (_kind == 'Options') ...[
                  const SizedBox(height: 16),
                  SetesTextField(
                    label: 'forms.interface.configOptions'.tr(),
                    hint: 'forms.interface.configOptionsHint'.tr(),
                    controller: _options,
                  ),
                ],
                const SizedBox(height: 16),
                SetesTextField(
                  label: 'forms.interface.configDefault'.tr(),
                  controller: _defaultContent,
                ),
                const SizedBox(height: 8),
                SetesCheckbox(
                  label: 'forms.interface.configScopeUserLabel'.tr(),
                  value: _scopeUser,
                  onChanged: (checked) =>
                      setState(() => _scopeUser = checked ?? false),
                ),
              ],
            ),
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
            onPressed: _submit,
          ),
        ],
      );
}
