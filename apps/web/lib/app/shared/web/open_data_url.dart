import 'package:flutter/foundation.dart';

import 'open_data_url_stub.dart'
    if (dart.library.html) 'open_data_url_web.dart' as impl;

/// Abre um conteúdo base64 (ex.: PDF do boleto devolvido pela API) numa nova
/// aba do navegador. Só faz algo no Flutter Web (alvo do setes-app); nas
/// demais plataformas devolve false para a tela oferecer outra saída.
Future<bool> openBase64InNewTab(String base64, {String mimeType = 'application/pdf'}) async {
  if (!kIsWeb) return false;
  return impl.openDataUrl('data:$mimeType;base64,$base64');
}
