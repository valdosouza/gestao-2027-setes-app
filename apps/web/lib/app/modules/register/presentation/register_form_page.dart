import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Descritor de campo (decisão 20): parametriza o formulário genérico.
class RegisterField {
  const RegisterField({
    required this.name,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.validator,
  });

  final String name;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
}

/// Fábrica de cadastros (decisão 20): formulário padrão do prompt —
/// campos do objeto + Salvar/Cancelar. Exclusão sempre LÓGICA
/// (deleted = 'S' — decisão 4), executada pelo backend.
class RegisterFormPage extends StatefulWidget {
  const RegisterFormPage({
    required this.title,
    required this.fields,
    required this.onSave,
    required this.onCancel,
    this.initialValues = const {},
    this.canSave = true,
    super.key,
  });

  final String title;
  final List<RegisterField> fields;
  final Map<String, String> initialValues;
  final Future<void> Function(Map<String, String> values) onSave;
  final VoidCallback onCancel;

  /// Privilégios 'insert'/'update' do usuário (decisão 21).
  final bool canSave;

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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await widget.onSave({
      for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText.title(widget.title),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    for (final field in widget.fields) ...[
                      SetesTextField(
                        label: field.label,
                        controller: _controllers[field.name],
                        obscureText: field.obscure,
                        keyboardType: field.keyboardType,
                        validator: field.validator,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SetesButton(
                    label: 'register.cancel'.tr(),
                    kind: SetesButtonKind.secondary,
                    onPressed: widget.onCancel,
                  ),
                  const SizedBox(width: 8),
                  if (widget.canSave)
                    SetesButton(label: 'register.save'.tr(), loading: _saving, onPressed: _save),
                ],
              ),
            ],
          ),
        ),
      );
}
