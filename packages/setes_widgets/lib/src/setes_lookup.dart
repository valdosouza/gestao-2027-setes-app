import 'package:flutter/material.dart';

/// Lista de apoio genérica de FK (skill campo-lookup-fk.md, padrão do
/// customer_register_city_list_widget do app antigo): filtro incremental no
/// topo, carga inicial na abertura, `ListView.separated` com `ListTile` +
/// `CircleAvatar` do id; retorna o item escolhido via `Navigator.pop`.
///
/// O pacote não depende de easy_localization: [title], [filterHint] e
/// [emptyText] chegam JÁ traduzidos pelo chamador (ex.: 'lookup.countries'.tr(),
/// 'register.filterHint'.tr(), 'register.emptyList'.tr()).
Future<T?> showSetesLookup<T>({
  required BuildContext context,
  required String title,
  required String filterHint,
  required String emptyText,
  required Future<List<T>> Function(String filter) onSearch,
  required int Function(T item) itemId,
  required String Function(T item) itemLabel,
}) =>
    showDialog<T>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: _SetesLookupBody<T>(
            title: title,
            filterHint: filterHint,
            emptyText: emptyText,
            onSearch: onSearch,
            itemId: itemId,
            itemLabel: itemLabel,
          ),
        ),
      ),
    );

class _SetesLookupBody<T> extends StatefulWidget {
  const _SetesLookupBody({
    required this.title,
    required this.filterHint,
    required this.emptyText,
    required this.onSearch,
    required this.itemId,
    required this.itemLabel,
  });

  final String title;
  final String filterHint;
  final String emptyText;
  final Future<List<T>> Function(String filter) onSearch;
  final int Function(T item) itemId;
  final String Function(T item) itemLabel;

  @override
  State<_SetesLookupBody<T>> createState() => _SetesLookupBodyState<T>();
}

class _SetesLookupBodyState<T> extends State<_SetesLookupBody<T>> {
  List<T> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search(''); // carga inicial já na abertura
  }

  Future<void> _search(String filter) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.onSearch(filter);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (err) {
      // Falha na consulta NUNCA deixa o dialog em loading infinito
      // (fix 2026-07-18): mostra a mensagem e permite tentar outro filtro.
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _error = err.toString();
      });
    }
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) return Center(child: Text(widget.emptyText));
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          leading: CircleAvatar(child: Text('${widget.itemId(item)}')),
          title: Text(widget.itemLabel(item)),
          onTap: () => Navigator.of(context).pop(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Cabeçalho no estilo AppBar — cores SEMPRE do tema (decisão 16).
        Container(
          color: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: colors.onPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: colors.onPrimary),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            onChanged: _search, // pesquisa incremental
            decoration: InputDecoration(
              hintText: widget.filterHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }
}
