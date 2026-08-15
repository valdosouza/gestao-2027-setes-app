import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../data/datasource/institution_datasource.dart';
import '../../domain/entity/object_institution.dart';
import '../../domain/entity/sync_api_key.dart';

/// Aba "Estabelecimento" — a ÚNICA aba não compartilhada do form
/// (skill cadastro-entidade-fiscal.md): campos específicos de tb_institution.
///
/// - schemaName: editável SÓ na inclusão (imutável na edição), padrão
///   `setes_<nome>`;
/// - active: readOnly na inclusão — quem ativa é a migração do schema no
///   backend (POST → commit → runMigrationsForSchema → active='S');
/// - Chave de Sincronização (tb_sync_api_key): seção AUTÔNOMA via datasource
///   (precedente da aba Interfaces) — só na edição; exibir/copiar/gerar.
class InstitutionTab extends StatefulWidget {
  const InstitutionTab({
    required this.value,
    required this.creating,
    required this.onChanged,
    this.institutionId,
    this.datasource,
    this.schemaNameFocus,
    this.schemaNameKey,
    super.key,
  });

  final ObjectInstitution value;
  final bool creating;
  final ValueChanged<ObjectInstitution> onChanged;

  /// null = inclusão (a chave só existe depois do salvar).
  final int? institutionId;
  final InstitutionDatasource? datasource;

  /// Ganchos da mecânica uma-pendência do form composto (R3) — opcionais:
  /// foco/marca dirigidos ao campo após o dialog da ponte.
  final FocusNode? schemaNameFocus;
  final GlobalKey<FormFieldState<String>>? schemaNameKey;

  @override
  State<InstitutionTab> createState() => _InstitutionTabState();
}

class _InstitutionTabState extends State<InstitutionTab> {
  late final TextEditingController _schemaName;
  late final TextEditingController _adminName;
  late final TextEditingController _adminNick;
  late final TextEditingController _adminEmail;
  late final TextEditingController _adminPassword;

  @override
  void initState() {
    super.initState();
    _schemaName = TextEditingController(text: widget.value.schemaName);
    final admin = widget.value.admin;
    _adminName     = TextEditingController(text: admin.nameCompany);
    _adminNick     = TextEditingController(text: admin.nickTrade);
    _adminEmail    = TextEditingController(text: admin.email);
    _adminPassword = TextEditingController(text: admin.password);
  }

  @override
  void dispose() {
    _schemaName.dispose();
    _adminName.dispose();
    _adminNick.dispose();
    _adminEmail.dispose();
    _adminPassword.dispose();
    super.dispose();
  }

  /// Mesmas regras do institutions.dto (bloco admin) — a marca inline nunca
  /// mente para a pendência (R3). Só valem na inclusão.
  String? _requiredAdmin(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'register.required'.tr() : null;

  String? _validateAdminEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'register.required'.tr();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'forms.institution.adminEmailInvalid'.tr();
    }
    return null;
  }

  String? _validateAdminPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'register.required'.tr();
    if (text.length < 5) return 'forms.institution.adminPasswordShort'.tr();
    return null;
  }

  /// Mesmo julgamento do salvar (required + padrão `setes_<nome>`) — a
  /// marca inline nunca mente para a pendência (R3). Só vale na inclusão.
  String? _validateSchemaName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'register.required'.tr();
    if (!RegExp(r'^setes_[a-z0-9_]+$').hasMatch(text)) {
      return 'forms.institution.schemaNameInvalid'.tr();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: SetesTextField(
                label: 'forms.institution.schemaName'.tr(),
                hint: 'forms.institution.schemaNameHint'.tr(),
                controller: _schemaName,
                focusNode: widget.schemaNameFocus,
                fieldKey: widget.schemaNameKey,
                readOnly: !widget.creating,
                autofocus: widget.creating,
                textInputAction: TextInputAction.done,
                validator: widget.creating ? _validateSchemaName : null,
                onChanged: (t) =>
                    widget.onChanged(widget.value.copyWith(schemaName: t)),
              ),
            ),
            const SizedBox(height: 8),
            // Na inclusão o checkbox é somente leitura (ativação = migração).
            ExcludeFocusTraversal(
              child: AbsorbPointer(
                absorbing: widget.creating,
                child: Opacity(
                  opacity: widget.creating ? 0.6 : 1,
                  child: SetesCheckbox(
                    label: 'forms.institution.active'.tr(),
                    value: widget.value.active,
                    onChanged: (v) => widget.onChanged(
                        widget.value.copyWith(active: v ?? false)),
                  ),
                ),
              ),
            ),
            // Administrador inicial: SÓ na inclusão (A2 — o cliente nasce
            // com dono; depois a manutenção é da aba Usuários).
            if (widget.creating) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('forms.institution.adminSection'.tr(),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('forms.institution.adminHint'.tr(),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: SetesTextField(
                  label: 'forms.institution.adminName'.tr(),
                  controller: _adminName,
                  validator: _requiredAdmin,
                  onChanged: (t) => widget.onChanged(widget.value.copyWith(
                      admin: widget.value.admin.copyWith(nameCompany: t))),
                ),
              ),
              const SizedBox(height: 8),
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: SetesTextField(
                  label: 'forms.institution.adminNick'.tr(),
                  controller: _adminNick,
                  validator: _requiredAdmin,
                  onChanged: (t) => widget.onChanged(widget.value.copyWith(
                      admin: widget.value.admin.copyWith(nickTrade: t))),
                ),
              ),
              const SizedBox(height: 8),
              FocusTraversalOrder(
                order: const NumericFocusOrder(3),
                child: SetesTextField(
                  label: 'forms.institution.adminEmail'.tr(),
                  hint: 'forms.institution.adminEmailHint'.tr(),
                  controller: _adminEmail,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateAdminEmail,
                  onChanged: (t) => widget.onChanged(widget.value.copyWith(
                      admin: widget.value.admin.copyWith(email: t))),
                ),
              ),
              const SizedBox(height: 8),
              FocusTraversalOrder(
                order: const NumericFocusOrder(4),
                child: SetesTextField(
                  label: 'forms.institution.adminPassword'.tr(),
                  hint: 'forms.institution.adminPasswordHint'.tr(),
                  controller: _adminPassword,
                  obscureText: true,
                  validator: _validateAdminPassword,
                  onChanged: (t) => widget.onChanged(widget.value.copyWith(
                      admin: widget.value.admin.copyWith(password: t))),
                ),
              ),
            ],
            if (widget.institutionId != null && widget.datasource != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _SyncApiKeySection(
                institutionId: widget.institutionId!,
                datasource: widget.datasource!,
              ),
            ],
          ],
        ),
      );
}

/// Seção da Chave de Sincronização (X-Api-Key do Sincronizador) — AUTÔNOMA
/// via datasource, fora do draft do bloc (precedente da aba Interfaces):
/// carrega no init; sem chave → botão Gerar (a API só cria quando não
/// existe; trocar chave de instalação em produção é intervenção manual).
/// Falhas/sucessos SEMPRE pela ponte de feedback (R1/R7).
class _SyncApiKeySection extends StatefulWidget {
  const _SyncApiKeySection({
    required this.institutionId,
    required this.datasource,
  });

  final int institutionId;
  final InstitutionDatasource datasource;

  @override
  State<_SyncApiKeySection> createState() => _SyncApiKeySectionState();
}

class _SyncApiKeySectionState extends State<_SyncApiKeySection> {
  final _apiKey = TextEditingController();
  SyncApiKey? _key;
  bool _loading = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  void _fail(Failure failure) {
    if (!mounted) return;
    showFailureFeedback(context, failure);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final key = await widget.datasource.getSyncApiKey(widget.institutionId);
      if (mounted) {
        setState(() {
          _key = key;
          _apiKey.text = key?.apiKey ?? '';
        });
      }
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final key =
          await widget.datasource.generateSyncApiKey(widget.institutionId);
      if (mounted) {
        setState(() {
          _key = key;
          _apiKey.text = key.apiKey;
        });
        await showSuccessFeedback(
            context, 'forms.institution.syncApiKeyGenerated');
      }
    } on Failure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const Failure(message: 'register.error'));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _key!.apiKey));
    if (mounted) {
      await showSuccessFeedback(context, 'forms.institution.syncApiKeyCopied');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SetesCircularProgressIndicator(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SetesText('forms.institution.syncApiKeySection'.tr()),
        const SizedBox(height: 8),
        if (_key == null) ...[
          SetesText('forms.institution.syncApiKeyEmpty'.tr()),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SetesButton(
              label: 'forms.institution.syncApiKeyGenerate'.tr(),
              icon: Icons.key,
              loading: _generating,
              onPressed: _generate,
            ),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: SetesTextField(
                  label: 'forms.institution.syncApiKey'.tr(),
                  controller: _apiKey,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              SetesIconButton(
                icon: Icons.copy,
                tooltip: 'forms.institution.syncApiKeyCopy'.tr(),
                onPressed: _copy,
              ),
            ],
          ),
      ],
    );
  }
}
