/// Stub para plataformas no-web.
/// Nunca se usa en runtime (siempre queda tras un guard kIsWeb),
/// pero necesario para que el compilador no-web no falle.
library;

import 'package:flutter/material.dart';

class WebPdfView extends StatelessWidget {
  final String url;
  const WebPdfView({super.key, required this.url});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
