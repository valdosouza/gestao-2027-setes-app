import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../domain/object_entity.dart';
import 'entity_list_common.dart';

/// Aba "Redes Sociais" da cadeia de entidade fiscal — COMPARTILHADA
/// (skill cadastro-entidade-fiscal.md). CRUD inline: lista + dialog de
/// add/edit + remover com confirmação. Kind único por lista (PK id+kind).
class SocialMediaListTab extends StatelessWidget {
  const SocialMediaListTab(
      {required this.items, required this.onChanged, super.key});

  final List<EntitySocialMedia> items;
  final ValueChanged<List<EntitySocialMedia>> onChanged;

  Future<void> _openDialog(BuildContext context, {int? index}) async {
    final editing = index != null ? items[index] : null;
    final takenKinds = {
      for (final (i, item) in items.indexed)
        if (i != index) item.kind,
    };
    final result = await showDialog<EntitySocialMedia>(
      context: context,
      builder: (_) =>
          _SocialMediaDialog(editing: editing, takenKinds: takenKinds),
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
        heroTag: 'entity_social_media_add',
        itemCount: items.length,
        onAdd: () => _openDialog(context),
        itemBuilder: (context, index) {
          final s = items[index];
          return SetesListTile(
            leading: CircleAvatar(
                child: SetesText(s.kind.isNotEmpty ? s.kind[0] : '?')),
            title: SetesText(s.kind),
            subtitle: (s.link ?? '').isEmpty ? null : SetesText(s.link!),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _remove(context, index),
            ),
            onTap: () => _openDialog(context, index: index),
          );
        },
      );
}

class _SocialMediaDialog extends StatefulWidget {
  const _SocialMediaDialog({required this.editing, required this.takenKinds});

  final EntitySocialMedia? editing;
  final Set<String> takenKinds;

  @override
  State<_SocialMediaDialog> createState() => _SocialMediaDialogState();
}

class _SocialMediaDialogState extends State<_SocialMediaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kind;
  late final TextEditingController _link;

  @override
  void initState() {
    super.initState();
    _kind = TextEditingController(text: widget.editing?.kind ?? '');
    _link = TextEditingController(text: widget.editing?.link ?? '');
  }

  @override
  void dispose() {
    _kind.dispose();
    _link.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(EntitySocialMedia(
      kind: _kind.text.trim(),
      link: _link.text.trim().isEmpty ? null : _link.text.trim(),
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
                          child: SetesText('forms.socialMedia.dialogTitle'.tr(),
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
                        label: 'forms.socialMedia.kind'.tr(),
                        controller: _kind,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        validator: kindValidator(widget.takenKinds),
                      ),
                      const SizedBox(height: 16),
                      SetesTextField(
                        label: 'forms.socialMedia.link'.tr(),
                        controller: _link,
                        keyboardType: TextInputType.url,
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
