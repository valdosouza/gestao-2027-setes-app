import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../feedback/form_pendency.dart';

/// Dialog do CANCELAMENTO DA NOTA (prompt_cancelamento_nota.md D13/H1 do
/// legado): confirmação humana + MOTIVO obrigatório (até 255), gravado no
/// evento C da nota. Compartilhado pela venda (orders) e pela ordem de
/// serviço (service-orders — Q-G16: o "Cancelar nota" vive no documento
/// faturado). Devolve o motivo via Navigator.pop; null = desistiu.
class CancelInvoiceDialog extends StatefulWidget {
  const CancelInvoiceDialog({required this.documentNumber, super.key});

  /// Identificação do documento (nº do pedido/OS — 1 nota por pedido).
  final String documentNumber;

  @override
  State<CancelInvoiceDialog> createState() => _CancelInvoiceDialogState();
}

class _CancelInvoiceDialogState extends State<CancelInvoiceDialog> {
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
    if (text.isEmpty) return 'forms.billing.cancelInvoiceReasonRequired';
    if (text.length > 255) return 'forms.billing.cancelInvoiceReasonTooLong';
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
        title: SetesText(
            'forms.billing.cancelInvoiceTitle'.tr(args: [widget.documentNumber])),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.billing.cancelInvoiceExplain'.tr()),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.billing.cancelInvoiceReason'.tr(),
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
            label: 'forms.billing.cancelInvoiceConfirm'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Abre o dialog — devolve o motivo confirmado ou null (desistiu).
Future<String?> showCancelInvoiceDialog(
        BuildContext context, String documentNumber) =>
    showDialog<String>(
      context: context,
      builder: (_) => CancelInvoiceDialog(documentNumber: documentNumber),
    );
