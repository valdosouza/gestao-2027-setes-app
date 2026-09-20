// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

/// Web: converte o data URL em Blob e abre em nova aba — data URLs grandes
/// (PDF) são bloqueadas por alguns navegadores quando abertas diretamente.
Future<bool> openDataUrl(String dataUrl) async {
  try {
    final comma = dataUrl.indexOf(',');
    final header = dataUrl.substring(5, comma);              // "application/pdf;base64"
    final mime = header.split(';').first;
    final bytes = base64Decode(dataUrl.substring(comma + 1));
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future<void>.delayed(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
    return true;
  } catch (_) {
    return false;
  }
}
