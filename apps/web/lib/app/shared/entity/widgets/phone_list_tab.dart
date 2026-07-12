import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../domain/object_entity.dart';
import 'entity_list_common.dart';

/// Aba "Fones" da cadeia de entidade fiscal — COMPARTILHADA
/// (skill cadastro-entidade-fiscal.md; tabela real tb_phone, SINGULAR).
/// CRUD inline: lista + dialog de add/edit + remover com confirmação.
class PhoneListTab extends StatelessWidget {
  const PhoneListTab({required this.items, required this.onChanged, super.key});

  final List<EntityPhone> items;
  final ValueChanged<List<EntityPhone>> onChanged;

  Future<void> _openDialog(BuildContext context, {int? index}) async {
    final editing = index != null ? items[index] : null;
    final takenKinds = {
      for (final (i, item) in items.indexed)
        if (i != index) item.kind,
    };
    final result = await showDialog<EntityPhone>(
      context: context,
      builder: (_) => _PhoneDialog(editing: editing, takenKinds: takenKinds),
    );
    if (result == null) return;
    final updated = [...items];
    if (index != null) {
      updated[index] = result;
    } else {
      updated.add(result);
    }
    onChanged(updated);
  }

  Future<void> _remove(BuildContext context, int index) async {
    if (!await confirmEntityItemDelete(context)) return;
    onChanged([...items]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) => EntityListScaffold(
        heroTag: 'entity_phone_add',
        itemCount: items.length,
        onAdd: () => _openDialog(context),
        itemBuilder: (context, index) {
          final p = items[index];
          final details = [
            if ((p.number ?? '').isNotEmpty) p.number!,
            if ((p.contact ?? '').isNotEmpty) p.contact!,
          ].join(' · ');
          return SetesListTile(
            leading: CircleAvatar(
                child: SetesText(p.kind.isNotEmpty ? p.kind[0] : '?')),
            title: SetesText(p.kind),
            subtitle: details.isEmpty ? null : SetesText(details),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _remove(context, index),
            ),
            onTap: () => _openDialog(context, index: index),
          );
        },
      );
}

class _PhoneDialog extends StatefulWidget {
  const _PhoneDialog({required this.editing, required this.takenKinds});

  final EntityPhone? editing;
  final Set<String> takenKinds;

  @override
  State<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends State<_PhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kind;
  late final TextEditingController _contact;
  late final TextEditingController _number;

  @override
  void initState() {
    super.initState();
    _kind    = TextEditingController(text: widget.editing?.kind ?? '');
    _contact = TextEditingController(text: widget.editing?.contact ?? '');
    _number  = TextEditingController(text: widget.editing?.number ?? '');
  }

  @override
  void dispose() {
    _kind.dispose();
    _contact.dispose();
    _number.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(EntityPhone(
      kind:    _kind.text.trim(),
      contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      number:  _number.text.trim().isEmpty ? null : _number.text.trim(),
    ));
  }

  String? _validateRequired(String? value) =>
      (value == null || value.trim().isEmpty) ? 'register.required'.tr() : null;

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                          child: SetesText('forms.phone.dialogTitle'.tr(),
                              style: Theme.of(context).textTheme.titleMedium)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, size: 30),
                        onPressed: _confirm,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SetesTextField(
                        label: 'forms.phone.kind'.tr(),
                        controller: _kind,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        validator: kindValidator(widget.takenKinds),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.phone.contact'.tr(),
                        controller: _contact,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.phone.number'.tr(),
                        controller: _number,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        validator: _validateRequired,
                        onSubmitted: (_) => _confirm(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
