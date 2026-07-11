import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Fábrica de cadastros (decisão 20 — composição + genéricos, não herança):
/// tela de pesquisa no contrato visual do customer_register
/// (skill criar-formulario-cadastro.md, item 5) — Scaffold com AppBar no
/// mesmo estilo do formulário (sem leading), filtro logo abaixo com sufixo
/// Icons.search, novo registro via FloatingActionButton (Icons.add),
/// ListView.separated com Divider, item com CircleAvatar (código) e clique
/// na linha inteira abre a edição.
class RegisterSearchPage<T> extends StatefulWidget {
  const RegisterSearchPage({
    required this.title,
    required this.columns,
    required this.rowBuilder,
    required this.onSearch,
    required this.onView,
    this.avatarBuilder,
    this.canView = true,
    this.onNew,
    super.key,
  });

  final String title;

  /// Descritor de campos do cadastro (decisão 20).
  /// Mantido por compatibilidade — a lista atual exibe rowBuilder.
  final List<String> columns;
  final List<String> Function(T item) rowBuilder;
  final Future<List<T>> Function(String filter) onSearch;
  final void Function(T item) onView;

  /// Texto do CircleAvatar do item (padrão do widget_customer_list:
  /// o código/id do registro). null = sem avatar.
  final String Function(T item)? avatarBuilder;

  /// Privilégio 'view' do usuário (decisão 21).
  final bool canView;

  /// Opcional: exibe FloatingActionButton (Icons.add) para novo registro
  /// e chama o callback ao clicar. null = sem botão de novo.
  final VoidCallback? onNew;

  @override
  State<RegisterSearchPage<T>> createState() => _RegisterSearchPageState<T>();
}

class _RegisterSearchPageState<T> extends State<RegisterSearchPage<T>> {
  final _filter = TextEditingController();
  List<T> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search(); // carga inicial na abertura (padrão da lista de apoio)
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final items = await widget.onSearch(_filter.text.trim());
    if (!mounted) return;
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

  Widget _buildList() {
    if (_loading) return const SetesCircularProgressIndicator();
    if (_items.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        final cells = widget.rowBuilder(item);
        return SetesListTile(
          leading: widget.avatarBuilder != null
              ? CircleAvatar(child: SetesText(widget.avatarBuilder!(item)))
              : null,
          title: SetesText(cells.isNotEmpty ? cells.first : ''),
          subtitle:
              cells.length > 1 ? SetesText(cells.skip(1).join(' · ')) : null,
          onTap: widget.canView ? () => widget.onView(item) : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.title),
        ),
        floatingActionButton: widget.onNew != null
            ? FloatingActionButton(
                onPressed: widget.onNew,
                child: const Icon(Icons.add),
              )
            : null,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesTextField(
                label: 'register.filter'.tr(),
                hint: 'register.filterHint'.tr(),
                controller: _filter,
                suffixIcon: Icons.search,
                onSuffixPressed: _search,
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      );
}
