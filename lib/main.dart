import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const HamzaApp());
}

class HamzaApp extends StatefulWidget {
  const HamzaApp({super.key});
  @override
  State<HamzaApp> createState() => _HamzaAppState();
}

class _HamzaAppState extends State<HamzaApp> {
  String status = 'Ready - Room 1234';
  MediaStream? _stream;
  final _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
  }

  Future<void> startAudio() async {
    setState(() => status = 'Asking for Mic...');
    var mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      setState(() => status = 'Mic DENIED - Allow Mic in Settings');
      return;
    }
    try {
      _stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      setState(() => status = 'MIC WORKING - Audio Call Started');
    } catch (e) {
      setState(() => status = 'Mic Error: $e');
    }
  }

  Future<void> startVideo() async {
    setState(() => status = 'Asking for Mic + Camera...');
    await Permission.microphone.request();
    await Permission.camera.request();
    try {
      _stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
      _localRenderer.srcObject = _stream;
      setState(() => status = 'VIDEO WORKING - Video Call Started');
    } catch (e) {
      setState(() => status = 'Video Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Hamza Jani'), backgroundColor: Colors.green),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Hamza Jani', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              SizedBox(width: 250, height: 180, child: RTCVideoView(_localRenderer)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: startAudio, child: const Text('AUDIO CALL')),
              const SizedBox(height: 15),
              ElevatedButton(onPressed: startVideo, child: const Text('VIDEO CALL')),
            ],
          ),
        ),
      ),
    );
  }
}
