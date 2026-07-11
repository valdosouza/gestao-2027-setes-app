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
  })  : isLookup = false,
        display = '',
        onPick = null,
        validatorMessage = null;

  /// Campo de FK com lista de apoio (skill campo-lookup-fk.md): renderiza
  /// [SetesLookupField] mostrando [display] (readOnly, fora do Tab);
  /// Icons.search chama [onPick], que abre showSetesLookup e guarda o id
  /// escolhido no ESTADO DA PÁGINA — o id nunca entra nos values do onSave.
  const RegisterField.lookup({
    required this.name,
    required this.label,
    required this.display,
    required this.onPick,
    this.validatorMessage,
  })  : isLookup = true,
        obscure = false,
        readOnly = true,
        keyboardType = null,
        validator = null;

  final String name;
  final String label;
  final bool obscure;

  /// Campo exibido mas não editável (ex.: código imutável na edição).
  final bool readOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  /// true = campo de FK (constructor [RegisterField.lookup]).
  final bool isLookup;

  /// Descrição atual do registro relacionado ('' se nada escolhido).
  final String display;

  /// Abre a lista de apoio (a página chama showSetesLookup e faz setState).
  final VoidCallback? onPick;

  /// Mensagem exibida pelo Form.validate() quando nada foi escolhido.
  final String? validatorMessage;
}

/// Fábrica de cadastros (decisão 20) — formulário no contrato visual do
/// customer_register (skill criar-formulario-cadastro.md) via [SetesFormShell].
///
/// ARQUITETURA_MODULOS.md: a fábrica é APRESENTAÇÃO PURA — não executa
/// operações. [onSave]/[onDelete] apenas DISPARAM eventos no bloc do módulo;
/// sucesso/erro viram SnackBar no BlocListener da página. O flag [saving]
/// vem do estado do bloc e desabilita as ações.
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
    this.saving = false,
    super.key,
  });

  final String title;
  final List<RegisterField> fields;
  final Map<String, String> initialValues;

  /// Dispara o evento de salvar no bloc com os values validados.
  final void Function(Map<String, String> values) onSave;
  final VoidCallback onCancel;

  /// Privilégios 'insert'/'update' do usuário (decisão 21).
  final bool canSave;

  /// Dispara o evento de excluir no bloc (a confirmação acontece AQUI,
  /// antes do disparo — exclusão sempre LÓGICA, decisão 4).
  final VoidCallback? onDelete;
  final bool canDelete;

  /// Estado do bloc: operação em andamento desabilita as ações.
  final bool saving;

  @override
  State<RegisterFormPage> createState() => _RegisterFormPageState();
}

class _RegisterFormPageState extends State<RegisterFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        if (!field.isLookup) // lookup: o id fica no estado da página
          field.name: TextEditingController(
              text: widget.initialValues[field.name] ?? ''),
    };
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSave({
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    });
  }

  Future<void> _confirmDelete() async {
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
    if (confirmed == true) widget.onDelete?.call();
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
    // Tabulação (skill, item 8): Tab segue a ordem declarada dos campos e
    // SÓ os editáveis (readOnly e lookup ficam fora); foco inicial no
    // primeiro editável; Enter avança (next) e finaliza no último (done).
    final editableIndexes = [
      for (final (index, field) in widget.fields.indexed)
        if (!field.isLookup && !field.readOnly) index,
    ];
    final firstEditable = editableIndexes.isEmpty ? -1 : editableIndexes.first;
    final lastEditable = editableIndexes.isEmpty ? -1 : editableIndexes.last;

    return SetesFormShell(
      title: widget.title,
      saving: widget.saving,
      onBack: widget.onCancel,
      onSave: widget.canSave ? _save : null,
      onDelete:
          widget.canDelete && widget.onDelete != null ? _confirmDelete : null,
      child: Form(
        key: _formKey,
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (index, field) in widget.fields.indexed) ...[
                if (field.isLookup)
                  // FK: readOnly e fora do Tab (SetesLookupField já exclui).
                  SetesLookupField(
                    label: field.label,
                    display: field.display,
                    onSearch: field.onPick ?? () {},
                    validatorMessage: field.validatorMessage,
                  )
                else
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
