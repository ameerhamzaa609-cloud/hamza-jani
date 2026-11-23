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
  String status = 'Ready - 2 Phone Call';
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
  }

  Future<RTCPeerConnection> _createPC() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          status = 'CONNECTED - You can talk now!';
        });
      }
    };
    pc.onConnectionState = (state) {
      setState(() => status = 'Connection: $state');
    };
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
    _localRenderer.srcObject = _localStream;
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });
    return pc;
  }

  Future<void> createOffer() async {
    setState(() => status = 'Asking Mic + Camera...');
    await Permission.microphone.request();
    await Permission.camera.request();
    _pc = await _createPC();
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await Future.delayed(const Duration(seconds: 2));
    final desc = await _pc!.getLocalDescription();
    final sdp = desc!.sdp!;
    setState(() {
      _codeController.text = sdp;
      status = 'OFFER Created! COPY this code, send to Phone 2 via WhatsApp';
    });
  }

  Future<void> joinWithOffer() async {
    setState(() => status = 'Asking Mic + Camera...');
    await Permission.microphone.request();
    await Permission.camera.request();
    _pc = await _createPC();
    await _pc!.setRemoteDescription(RTCSessionDescription(_codeController.text, 'offer'));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await Future.delayed(const Duration(seconds: 2));
    final desc2 = await _pc!.getLocalDescription();
    final sdp2 = desc2!.sdp!;
    setState(() {
      _codeController.text = sdp2;
      status = 'ANSWER Created! COPY this code, send back to Phone 1';
    });
  }

  Future<void> setAnswer() async {
    await _pc!.setRemoteDescription(RTCSessionDescription(_codeController.text, 'answer'));
    setState(() => status = 'ANSWER Set! Waiting to connect...');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          leading: const Padding(
            padding: EdgeInsets.all(6),
            child: CircleAvatar(
              backgroundImage: AssetImage('assets/logo.png'),
            ),
          ),
          title: const Text('Hamza Jani - 2 Phone Call'),
          backgroundColor: Colors.green,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 55,
                backgroundImage: AssetImage('assets/logo.png'),
              ),
              const SizedBox(height: 10),
              const Text('Hamza Jani', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: SizedBox(height: 140, child: RTCVideoView(_localRenderer, mirror: true))),
                  const SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 140, child: RTCVideoView(_remoteRenderer))),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Local (You) - Remote (Friend)', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 15),
              TextField(
                controller: _codeController,
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste CODE here...'),
