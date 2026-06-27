import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DebugWebViewApp());
}

class DebugWebViewApp extends StatefulWidget {
  const DebugWebViewApp({super.key});

  @override
  State<DebugWebViewApp> createState() => _DebugWebViewAppState();
}

class _DebugWebViewAppState extends State<DebugWebViewApp> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final params = const PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse('https://www.youtube.com/embed/dQw4w9WgXcQ'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Debug WebView')),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
