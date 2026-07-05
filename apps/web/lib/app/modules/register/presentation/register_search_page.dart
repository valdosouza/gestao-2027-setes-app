import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Fábrica de cadastros (decisão 20 — composição + genéricos, não herança):
/// tela de pesquisa padrão do prompt (seção Workflow 3) — lista com campos
/// de identificação, filtro, botão Pesquisar e botão Visualizar.
class RegisterSearchPage<T> extends StatefulWidget {
  const RegisterSearchPage({
    required this.title,
    required this.columns,
    required this.rowBuilder,
    required this.onSearch,
    required this.onView,
    this.canView = true,
    super.key,
  });

  final String title;

  /// Descritor de campos do cadastro (decisão 20).
  final List<String> columns;
  final List<String> Function(T item) rowBuilder;
  final Future<List<T>> Function(String filter) onSearch;
  final void Function(T item) onView;

  /// Privilégio 'view' do usuário (decisão 21).
  final bool canView;

  @override
  State<RegisterSearchPage<T>> createState() => _RegisterSearchPageState<T>();
}

class _RegisterSearchPageState<T> extends State<RegisterSearchPage<T>> {
  final _filter = TextEditingController();
  List<T> _items = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    final items = await widget.onSearch(_filter.text.trim());
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesText.title(widget.title),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: SetesTextField(label: 'register.filter'.tr(), controller: _filter, onSubmitted: (_) => _search())),
                const SizedBox(width: 8),
                SetesButton(label: 'register.search'.tr(), loading: _loading, onPressed: _search),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const SetesCircularProgressIndicator()
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final cells = widget.rowBuilder(item);
                        return SetesListTile(
                          title: SetesText(cells.isNotEmpty ? cells.first : ''),
                          subtitle: cells.length > 1 ? SetesText(cells.skip(1).join(' · ')) : null,
                          trailing: widget.canView
                              ? SetesButton(
                                  label: 'register.view'.tr(),
                                  kind: SetesButtonKind.text,
                                  onPressed: () => widget.onView(item),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      );
}
