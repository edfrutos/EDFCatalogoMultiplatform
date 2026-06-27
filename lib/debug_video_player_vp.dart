import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: VideoPlayerDemo()))));
}

class VideoPlayerDemo extends StatefulWidget {
  const VideoPlayerDemo({super.key});

  @override
  State<VideoPlayerDemo> createState() => _VideoPlayerDemoState();
}

class _VideoPlayerDemoState extends State<VideoPlayerDemo> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse('https://samplelib.com/lib/preview/mp4/sample-5s.mp4'),
    )
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }).catchError((e) {
        setState(() {
          _error = e.toString();
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text('Error: $_error');
    }
    if (!_initialized) {
      return const CircularProgressIndicator();
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio == 0
          ? 16 / 9
          : _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
