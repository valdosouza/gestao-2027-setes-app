import 'package:core/core.dart' show Failure;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Descritor de campo (decisão 20): parametriza o formulário genérico.
class RegisterField {
  const RegisterField({
    required this.name,
    required this.label,
    this.obscure = false,
    this.readOnly = false,
    this.keyboardType,
    this.validator,
  });

  final String name;
  final String label;
  final bool obscure;

  /// Campo exibido mas não editável (ex.: código imutável na edição).
  final bool readOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
}

/// Fábrica de cadastros (decisão 20): formulário padrão no contrato visual do
/// customer_register (skill criar-formulario-cadastro.md) — Scaffold aninhado
/// com AppBar própria: voltar (sem salvar), salvar (check) e excluir
/// (delete_outline, com confirmação). Exclusão sempre LÓGICA
/// (deleted = 'S' — decisão 4), executada pelo backend.
/// Sucesso/erro comunicados via SnackBar (register.saved/deleted/error).
class RegisterFormPage extends StatefulWidget {
  const RegisterFormPage({
    required this.title,
    required this.fields,
    required this.onSave,
    required this.onCancel,
    this.initialValues = const {},
    this.canSave = true,
    this.onDelete,
    this.canDelete = false,
    super.key,
  });

  final String title;
  final List<RegisterField> fields;
  final Map<String, String> initialValues;
  final Future<void> Function(Map<String, String> values) onSave;
  final VoidCallback onCancel;

  /// Privilégios 'insert'/'update' do usuário (decisão 21).
  final bool canSave;

  /// Opcional: exclui o registro (soft-delete) após confirmação.
  final Future<void> Function()? onDelete;
  final bool canDelete;

  @override
  State<RegisterFormPage> createState() => _RegisterFormPageState();
}

class _RegisterFormPageState extends State<RegisterFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        field.name: TextEditingController(text: widget.initialValues[field.name] ?? ''),
    };
  }

  void _notify(ScaffoldMessengerState messenger, String message) =>
      messenger.showSnackBar(SnackBar(content: SetesText(message)));

  String _errorMessage(Object err) =>
      err is Failure ? err.message : 'register.error'.tr();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.onSave({
        for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
      });
      _notify(messenger, 'register.saved'.tr());
    } catch (err) {
      _notify(messenger, _errorMessage(err));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.onDelete!();
      _notify(messenger, 'register.deleted'.tr());
    } catch (err) {
      _notify(messenger, _errorMessage(err));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tabulação (feedback do Valdo 2026-07-11): Tab segue a ordem declarada
    // dos campos; readOnly fica fora da sequência; foco inicial no primeiro
    // campo editável; Enter avança (next) e finaliza no último (done).
    final firstEditable =
        widget.fields.indexWhere((f) => !f.readOnly);
    final lastEditable =
        widget.fields.lastIndexWhere((f) => !f.readOnly);

    return SetesFormShell(
      title: widget.title,
      onBack: widget.onCancel,
      onSave: widget.canSave ? _save : null,
      onDelete: (widget.canDelete && widget.onDelete != null) ? _delete : null,
      saving: _saving,
      child: Form(
        key: _formKey,
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (index, field) in widget.fields.indexed) ...[
                FocusTraversalOrder(
                  order: NumericFocusOrder(index.toDouble()),
                  child: SetesTextField(
                    label: field.label,
                    controller: _controllers[field.name],
                    obscureText: field.obscure,
                    readOnly: field.readOnly,
                    autofocus: index == firstEditable,
                    keyboardType: field.keyboardType,
                    textInputAction: index == lastEditable
                        ? TextInputAction.done
                        : TextInputAction.next,
                    validator: field.validator,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
