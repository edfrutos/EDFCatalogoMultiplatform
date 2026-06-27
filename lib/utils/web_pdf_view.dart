/// Visor de PDF en Flutter Web usando un <iframe> nativo del browser.
/// Chrome/Firefox tienen soporte PDF nativo — no necesita CORS en S3.
/// Usa dart:html (no package:web) para evitar conflictos de tipo File.
library;

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebPdfView extends StatefulWidget {
  final String url;
  const WebPdfView({super.key, required this.url});

  @override
  State<WebPdfView> createState() => _WebPdfViewState();
}

class _WebPdfViewState extends State<WebPdfView> {
  static int _counter = 0;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'edf-pdf-${_counter++}';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) {
        final iframe = html.IFrameElement()
          ..src = widget.url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
