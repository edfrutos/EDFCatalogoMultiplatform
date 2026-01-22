import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const DebugPlayerApp());
}

class DebugPlayerApp extends StatefulWidget {
  const DebugPlayerApp({super.key});

  @override
  State<DebugPlayerApp> createState() => _DebugPlayerAppState();
}

class _DebugPlayerAppState extends State<DebugPlayerApp> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        vo: 'libmpv',
        hwdec: 'auto',
        width: 1280,
        height: 720,
      ),
    );

    _player.open(
      Media('https://samplelib.com/lib/preview/mp4/sample-5s.mp4'),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            width: 640,
            height: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.white24),
              ),
              child: Video(
                controller: _controller,
                controls: AdaptiveVideoControls,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
