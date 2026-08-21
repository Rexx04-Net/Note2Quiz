// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

void downloadFileBytes(List<int> bytes, String filename) {
  try {
    final base64Data = base64Encode(bytes);
    final dataUri = 'data:text/calendar;charset=utf-8;base64,$base64Data';
    final anchor = html.AnchorElement(href: dataUri)
      ..setAttribute("download", filename)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
  } catch (e) {
    // Fallback using Blob
    final blob = html.Blob([bytes], 'text/calendar');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
  }
}

void openWebUrl(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (_) {}
}
