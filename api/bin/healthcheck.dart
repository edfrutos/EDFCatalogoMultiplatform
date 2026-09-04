// Binario minúsculo para el HEALTHCHECK de Docker.
// La imagen final es FROM scratch (sin shell ni wget/curl), así que el
// healthcheck no puede ser un comando de shell: tiene que ser un ejecutable.
import 'dart:io';

Future<void> main() async {
  final port = Platform.environment['API_PORT'] ?? '8080';
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('http://localhost:$port/health'))
        .timeout(const Duration(seconds: 3));
    final res = await req.close().timeout(const Duration(seconds: 3));
    exit(res.statusCode == 200 ? 0 : 1);
  } catch (_) {
    exit(1);
  } finally {
    client.close(force: true);
  }
}
