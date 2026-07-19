import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../data/datasource/customer_partnership_datasource.dart';
import '../../domain/entity/customer_partnership.dart';

/// Aba "Parceria" do cadastro de Cliente (Parceria v2 — decisões D1–D7 do
/// Valdo): a parceria nasce da ANGARIAÇÃO — colaboradores que trouxeram
/// e/ou atendem este cliente, cada um com seu percentual.
///
/// Aba AUTÔNOMA (molde das abas Interfaces/Usuários do institution): fora
/// do draft do bloc — carrega no GET ao abrir, edita a lista local (dialog
/// incluir/editar + remover com confirmação) e grava com o botão salvar DA
/// ABA (PUT com a lista completa; vazia remove a parceria). Total dos
/// percentuais ATIVOS ao vivo com teto de 90 (10% fixos da Setes). Só na
/// edição (o cliente precisa existir).
class CustomerPartnershipTab extends StatefulWidget {
  const CustomerPartnershipTab({
    required this.customerId,
    required this.datasource,
    super.key,
  });

  /// null = inclusão (aba orienta salvar o cliente primeiro).
  final int? customerId;
  final CustomerPartnershipDatasource datasource;

  @override
  State<CustomerPartnershipTab> createState() =>
      _CustomerPartnershipTabState();
}

class _CustomerPartnershipTabState extends State<CustomerPartnershipTab> {
  List<CustomerPartnershipPartner> _partners = [];
  bool _loading = false;
  bool _saving = false;

  /// Total dos percentuais ATIVOS (ao vivo — teto 90; suspensos ficam fora).
  double get _totalActiveRate => _partners.fold(
      0, (sum, partner) => partner.active ? sum + partner.rate : sum);

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) _load();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final partners = await widget.datasource.getPartners(widget.customerId!);
      if (mounted) setState(() => _partners = partners);
    } on Failure catch (failure) {
      if (mounted) _snack(failure.message);
    } catch (_) {
      if (mounted) _snack('register.error'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dialog de parceiro: incluir (colaborador via lookup + percentual +
  /// ativo) ou editar um existente (colaborador é a chave da linha —
  /// travado na edição).
  Future<void> _openPartnerDialog(
      {CustomerPartnershipPartner? existing}) async {
    final result = await showDialog<CustomerPartnershipPartner>(
      context: context,
      builder: (_) => _PartnerDialog(
        datasource: widget.datasource,
        existing: existing,
        usedCollaboratorIds: {
          for (final partner in _partners)
            if (partner.collaboratorId != existing?.collaboratorId)
              partner.collaboratorId,
        },
      ),
    );
    if (result == null) return;
    setState(() {
      final index = _partners
          .indexWhere((p) => p.collaboratorId == result.collaboratorId);
      if (index >= 0) {
        _partners[index] = result;
      } else {
        _partners.add(result);
      }
    });
  }

  /// Remoção na linha com confirmação (a gravação só acontece no salvar).
  Future<void> _removePartner(CustomerPartnershipPartner partner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('register.confirmDelete'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'register.delete'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) setState(() => _partners.remove(partner));
  }

  /// Salvar DA ABA: PUT com a lista completa (vazia remove a parceria).
  Future<void> _save() async {
    if (_totalActiveRate > 90) {
      _snack('forms.partnership.rateSumExceeded'.tr());
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.datasource.putPartners(widget.customerId!, _partners);
      if (mounted) {
        _snack('register.saved'.tr());
        await _load();
      }
    } on Failure catch (failure) {
      if (mounted) _snack(failure.message);
    } catch (_) {
      if (mounted) _snack('register.error'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildPartnerTile(CustomerPartnershipPartner partner) =>
      SetesListTile(
        leading: CircleAvatar(child: SetesText('${partner.collaboratorId}')),
        title: SetesText(partner.collaboratorName ?? ''),
        subtitle: SetesText([
          'forms.partnership.rateRow'
              .tr(args: [partnershipRate(partner.rate)]),
          // Selo do parceiro: suspenso fica fora da soma dos ativos.
          partner.active
              ? 'forms.partnership.active'.tr()
              : 'forms.partnership.suspended'.tr(),
        ].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'forms.partnership.editPartner'.tr(),
              onPressed: () => _openPartnerDialog(existing: partner),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'forms.partnership.removePartner'.tr(),
              onPressed: () => _removePartner(partner),
            ),
          ],
        ),
        onTap: () => _openPartnerDialog(existing: partner),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.customerId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SetesText('forms.customer.partnershipSaveFirst'.tr()),
        ),
      );
    }
    if (_loading) return const SetesCircularProgressIndicator();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Conceito da Parceria v2: angariação do cliente.
        SetesText(
          'forms.partnership.concept'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SetesText.title('forms.partnership.partners'.tr()),
        const SizedBox(height: 8),
        if (_partners.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SetesText('forms.partnership.noPartners'.tr()),
          )
        else
          ...[
            for (final partner in _partners) ...[
              _buildPartnerTile(partner),
              const Divider(height: 1),
            ],
          ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SetesButton(
            label: 'forms.partnership.addPartner'.tr(),
            icon: Icons.add,
            onPressed: () => _openPartnerDialog(),
          ),
        ),
        const SizedBox(height: 12),
        SetesText(
          'forms.partnership.totalRate'
              .tr(args: [partnershipRate(_totalActiveRate)]),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        SetesText(
          'forms.partnership.setesShare'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SetesButton(
            label: 'register.save'.tr(),
            icon: Icons.check,
            onPressed: _saving ? () {} : _save,
          ),
        ),
      ],
    );
  }
}

/// Dialog de parceiro: colaborador (lookup /api/collaborators) + percentual
/// (> 0 e ≤ 90, 2 casas) + ativo. Na edição o colaborador é travado (chave
/// da linha na tb_partnership) — só percentual e ativo mudam. Devolve o
/// [CustomerPartnershipPartner] via Navigator.pop.
class _PartnerDialog extends StatefulWidget {
  const _PartnerDialog({
    required this.datasource,
    required this.usedCollaboratorIds,
    this.existing,
  });

  final CustomerPartnershipDatasource datasource;

  /// Colaboradores já usados nos DEMAIS parceiros (não pode repetir).
  final Set<int> usedCollaboratorIds;
  final CustomerPartnershipPartner? existing;

  @override
  State<_PartnerDialog> createState() => _PartnerDialogState();
}

class _PartnerDialogState extends State<_PartnerDialog> {
  late final TextEditingController _rate;

  int? _collaboratorId;
  String _collaboratorName = '';
  bool _active = true;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _collaboratorId   = widget.existing?.collaboratorId;
    _collaboratorName = widget.existing?.collaboratorName ?? '';
    _active           = widget.existing?.active ?? true;
    _rate = TextEditingController(
        text: widget.existing == null
            ? ''
            : partnershipRate(widget.existing!.rate));
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _pickCollaborator() async {
    final picked = await showSetesLookup<CollaboratorLookupItem>(
      context: context,
      title: 'lookup.collaborators'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.collaborators,
      itemId: (c) => c.id,
      itemLabel: (c) => c.display,
    );
    if (picked != null) {
      setState(() {
        _collaboratorId   = picked.id;
        _collaboratorName = picked.display;
      });
    }
  }

  void _warn(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  void _confirm() {
    if (_collaboratorId == null) {
      _warn('register.requiredField'
          .tr(args: ['forms.partnership.collaborator'.tr()]));
      return;
    }
    if (widget.usedCollaboratorIds.contains(_collaboratorId)) {
      _warn('forms.partnership.duplicatePartner'.tr());
      return;
    }
    final parsed =
        double.tryParse(_rate.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0 || parsed > 90) {
      _warn('forms.partnership.rateInvalid'.tr());
      return;
    }
    // 2 casas decimais (padrão do percentual da parceria).
    final rate = (parsed * 100).round() / 100;
    Navigator.of(context).pop(CustomerPartnershipPartner(
      collaboratorId:   _collaboratorId!,
      collaboratorName: _collaboratorName,
      rate:             rate,
      active:           _active,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText(_editing
            ? 'forms.partnership.editPartner'.tr()
            : 'forms.partnership.addPartner'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_editing)
                SetesTextField(
                  key: ValueKey('collaborator-locked-$_collaboratorId'),
                  label: 'forms.partnership.collaborator'.tr(),
                  controller:
                      TextEditingController(text: _collaboratorName),
                  readOnly: true,
                )
              else
                SetesLookupField(
                  label: 'forms.partnership.collaborator'.tr(),
                  display: _collaboratorName,
                  onSearch: _pickCollaborator,
                ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.partnership.rate'.tr(),
                controller: _rate,
                autofocus: _editing,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _confirm(),
              ),
              const SizedBox(height: 8),
              SetesCheckbox(
                label: 'forms.partnership.active'.tr(),
                value: _active,
                onChanged: (checked) =>
                    setState(() => _active = checked ?? true),
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
            onPressed: _confirm,
          ),
        ],
      );
}
