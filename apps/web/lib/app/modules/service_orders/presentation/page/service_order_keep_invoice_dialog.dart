import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/form_pendency.dart';
import '../../domain/entity/service_order_fiscal_entity.dart';

/// Dialog do "Manter a nota" (D-F67, Valdo 2026-10-10) — irmão do dialog de
/// motivo do cancelamento (`shared/billing/cancel_invoice_dialog.dart`, mesmo
/// molde: confirmação humana + MOTIVO obrigatório até 255, uma pendência por
/// vez). A NFS-e da nota foi SUBSTITUÍDA no fisco (e105102) por outra que o
/// ERP não conhece; manter registra a decisão de NÃO cancelar a nota — nada
/// é desfeito. Nasce no módulo (só a OS tem a seção "No fisco"); promove
/// para `shared/` quando um 2º módulo precisar. Devolve o motivo via
/// Navigator.pop; null = desistiu.
class KeepInvoiceDialog extends StatefulWidget {
  const KeepInvoiceDialog({required this.documentNumber, super.key});

  /// Identificação do documento (nº da OS — 1 nota por pedido).
  final String documentNumber;

  @override
  State<KeepInvoiceDialog> createState() => _KeepInvoiceDialogState();
}

class _KeepInvoiceDialogState extends State<KeepInvoiceDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();
  final _reasonKey = GlobalKey<FormFieldState<String>>();

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  String? _validateReason() {
    final text = _reason.text.trim();
    if (text.isEmpty) return 'forms.serviceOrder.fiscalKeepReasonRequired';
    if (text.length > fiscalCancelWaiverReasonMax) {
      return 'forms.serviceOrder.fiscalKeepReasonTooLong';
    }
    return null;
  }

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'reason',
          validate: _validateReason,
          focusNode: _reasonFocus,
          fieldKey: _reasonKey),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.serviceOrder.fiscalKeepTitle'
            .tr(args: [widget.documentNumber])),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.serviceOrder.fiscalKeepExplain'.tr()),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.fiscalKeepReason'.tr(),
                controller: _reason,
                focusNode: _reasonFocus,
                fieldKey: _reasonKey,
                autofocus: true,
                validator: (_) => _validateReason()?.tr(),
                // marca da pendência some ao corrigir (achado do passeio nº 2)
                onChanged: (_) {
                  final state = _reasonKey.currentState;
                  if (state != null && state.hasError) state.validate();
                },
                onSubmitted: (_) => _confirm(),
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
            label: 'forms.serviceOrder.fiscalKeep'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Abre o dialog — devolve o motivo confirmado ou null (desistiu).
Future<String?> showKeepInvoiceDialog(
        BuildContext context, String documentNumber) =>
    showDialog<String>(
      context: context,
      builder: (_) => KeepInvoiceDialog(documentNumber: documentNumber),
    );
