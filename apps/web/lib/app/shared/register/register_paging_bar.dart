import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../interface_config/datasource/interface_config_datasource.dart';

/// Barra de paginação das listas (prompt_paginacao_telas_pesquisa.md, D1):
/// total à esquerda; seletor de itens/página e navegação « página X de Y »
/// à direita. Extraída da fábrica [RegisterSearchPage] (Onda 4) para as
/// telas de PROCESSO fora da fábrica (service_orders, settlements) usarem
/// a MESMA barra no rodapé das suas listas próprias.
///
/// Troca de tamanho: PERSISTE a escolha como override do usuário (config
/// page_size, D4 — silencioso: falha não quebra a tela) quando
/// [configModuleKey] está presente — o callback só precisa recarregar a
/// lista na página 1.
class RegisterPagingBar extends StatelessWidget {
  const RegisterPagingBar({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.configModuleKey,
    super.key,
  });

  /// Opções do seletor de itens por página (paginação D5).
  static const pageSizeOptions = [10, 25, 50, 100];

  /// Página corrente (1-based, como na API).
  final int page;
  final int pageSize;

  /// Total de registros do filtro corrente (D2) — exibido na barra.
  final int total;

  /// Chave do módulo para persistir o override page_size do usuário (D4).
  /// null = não persiste (só notifica [onPageSizeChanged]).
  final String? configModuleKey;

  /// Usuário navegou para outra página (1-based).
  final void Function(int page) onPageChanged;

  /// Usuário trocou o tamanho da página (null desabilita o seletor).
  final void Function(int pageSize)? onPageSizeChanged;

  int get _pageCount =>
      total <= 0 || pageSize <= 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  /// Troca de tamanho: persiste o override do usuário (config page_size,
  /// D4 — silencioso: falha não quebra a tela) e avisa o módulo recarregar.
  void _changePageSize(int? size) {
    if (size == null || size == pageSize) return;
    final moduleKey = configModuleKey;
    if (moduleKey != null) {
      Modular.get<InterfaceConfigDatasource>()
          .saveUserValue(moduleKey, 'page_size', '$size')
          .catchError((_) {});
    }
    onPageSizeChanged?.call(size);
  }

  /// Barra de paginação (D1): total à esquerda; seletor de itens/página e
  /// navegação à direita. Wrap: quebra linha em telas estreitas (Android).
  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    final sizes = {...pageSizeOptions, pageSize}.toList()..sort();
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        SetesText('register.totalRecords'.plural(total)),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            SetesText('register.itemsPerPage'.tr()),
            DropdownButton<int>(
              value: pageSize,
              underline: const SizedBox.shrink(),
              items: [
                for (final size in sizes)
                  DropdownMenuItem(value: size, child: SetesText('$size')),
              ],
              onChanged: onPageSizeChanged != null ? _changePageSize : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'register.previousPage'.tr(),
              onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            ),
            SetesText('register.pageOf'.tr(args: ['$page', '$pageCount'])),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'register.nextPage'.tr(),
              onPressed:
                  page < pageCount ? () => onPageChanged(page + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
