import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import 'register_config_button.dart';
import 'register_paging_bar.dart';

/// Fábrica de cadastros (decisão 20 — composição + genéricos, não herança):
/// tela de pesquisa no contrato visual do customer_register
/// (skill criar-formulario-cadastro.md, item 5) — AppBar no mesmo estilo do
/// formulário (sem leading), filtro logo abaixo com sufixo Icons.search,
/// novo registro via FloatingActionButton (Icons.add), ListView.separated
/// com CircleAvatar (código) e clique na linha inteira abre a edição.
///
/// ARQUITETURA_MODULOS.md: apresentação PURA, controlada pelo bloc do
/// módulo — recebe [items]/[loading] prontos e apenas notifica intenções
/// ([onFilterChanged], [onNew], [onView]). Não busca dados sozinha:
/// a carga inicial é responsabilidade do bloc (evento na abertura da página).
class RegisterSearchPage<T> extends StatefulWidget {
  const RegisterSearchPage({
    required this.title,
    required this.items,
    required this.rowBuilder,
    required this.onFilterChanged,
    required this.onView,
    this.loading = false,
    this.avatarBuilder,
    this.canView = true,
    this.onNew,
    this.actions,
    this.banner,
    this.configModuleKey,
    this.page,
    this.pageSize,
    this.total,
    this.onPageChanged,
    this.onPageSizeChanged,
    super.key,
  });

  /// Opções do seletor de itens por página (paginação D5) — a barra em si
  /// vive no widget compartilhado [RegisterPagingBar] (Onda 4).
  static const pageSizeOptions = RegisterPagingBar.pageSizeOptions;

  final String title;

  /// Ações extras do AppBar da lista. null = sem ações.
  final List<Widget>? actions;

  /// PADRÃO do produto (Framework de Configurações, decisão 11 — ajuste
  /// 2026-08-03): toda lista de cadastro informa a CHAVE do seu módulo; a
  /// engrenagem ([RegisterConfigButton]) só APARECE se o módulo tem
  /// configurações no catálogo — ícone visível = existe algo a configurar.
  /// Abre /home/interface-configs/ já filtrado na interface; o voltar do
  /// painel retorna para ESTA tela (returnTo).
  final String? configModuleKey;

  /// Widget informativo entre o filtro e a lista (ex.: aviso de filtro de
  /// carteira travado — piloto da decisão 15). null = sem banner.
  final Widget? banner;

  /// Itens prontos, vindos do estado do bloc.
  final List<T> items;

  /// true enquanto o bloc carrega — mostra o indicador de progresso.
  final bool loading;

  /// Primeira célula = título da linha; demais = subtítulo (' · ').
  final List<String> Function(T item) rowBuilder;

  /// Dispara a pesquisa no bloc (Enter ou clique na lupa).
  final void Function(String filter) onFilterChanged;
  final void Function(T item) onView;

  /// Texto do CircleAvatar do item (padrão do widget_customer_list:
  /// o código/id do registro). null = sem avatar.
  final String Function(T item)? avatarBuilder;

  /// Privilégio 'view' do usuário (decisão 21).
  final bool canView;

  /// Opcional: exibe FloatingActionButton (Icons.add) para novo registro
  /// e chama o callback ao clicar. null = sem botão de novo.
  final VoidCallback? onNew;

  /// Paginação (prompt_paginacao_telas_pesquisa.md, D1/D9): com [page],
  /// [pageSize], [total] e [onPageChanged] preenchidos a lista ganha a
  /// barra « anterior | página X de Y | próxima » + seletor de itens por
  /// página no rodapé. Todos null = comportamento antigo (telas ainda não
  /// migradas convivem com a fábrica nova).
  final int? page;
  final int? pageSize;

  /// Total de registros do filtro corrente (D2) — exibido na barra.
  final int? total;

  /// Usuário navegou para outra página (1-based).
  final void Function(int page)? onPageChanged;

  /// Usuário trocou o tamanho da página. A fábrica PERSISTE a escolha como
  /// override do usuário (config page_size, D4) quando [configModuleKey]
  /// está presente — o callback só precisa recarregar a lista na página 1.
  final void Function(int pageSize)? onPageSizeChanged;

  @override
  State<RegisterSearchPage<T>> createState() => _RegisterSearchPageState<T>();
}

class _RegisterSearchPageState<T> extends State<RegisterSearchPage<T>> {
  final _filter = TextEditingController();

  void _search() => widget.onFilterChanged(_filter.text.trim());

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  bool get _paged =>
      widget.page != null &&
      widget.pageSize != null &&
      widget.total != null &&
      widget.onPageChanged != null;

  Widget _buildList() {
    if (widget.loading) return const SetesCircularProgressIndicator();
    if (widget.items.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    return ListView.separated(
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = widget.items[index];
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
          actions: [
            ...?widget.actions,
            if (widget.configModuleKey != null)
              RegisterConfigButton(moduleKey: widget.configModuleKey!),
          ],
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
              if (widget.banner != null) ...[
                const SizedBox(height: 8),
                widget.banner!,
              ],
              const SizedBox(height: 16),
              Expanded(child: _buildList()),
              if (_paged) ...[
                const Divider(height: 1),
                const SizedBox(height: 4),
                RegisterPagingBar(
                  page: widget.page!,
                  pageSize: widget.pageSize!,
                  total: widget.total!,
                  configModuleKey: widget.configModuleKey,
                  onPageChanged: widget.onPageChanged!,
                  onPageSizeChanged: widget.onPageSizeChanged,
                ),
              ],
            ],
          ),
        ),
      );
}
