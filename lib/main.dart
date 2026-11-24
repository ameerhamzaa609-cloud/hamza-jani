import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String initError = '';
  try {
    await Firebase.initializeApp();
  } catch (e) {
    initError = '$e';
  }
  runApp(HamzaApp(initError: initError));
}

class HamzaApp extends StatelessWidget {
  final String initError;
  const HamzaApp({super.key, required this.initError});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: initError.isNotEmpty
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Firebase Error:\n\n$initError\n\nCheck google-services.json in 【entity-GitHub¦canonical_name=GitHub】', textAlign: TextAlign.center),
                ),
              ),
            )
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasData) return const HomeScreen();
                return const AuthScreen();
              },
            ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String msg = 'Create your User ID';
  bool isLogin = false;
  String emailFromId(String id) => '${id.trim().toLowerCase()}@hamzajani.app';
  Future<void> submit() async {
    final id = _idCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (id.isEmpty || pass.length < 6) {
      setState(() => msg = 'User ID needed and Password must be 6+');
      return;
    }
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailFromId(id), password: pass);
      } else {
        if (name.isEmpty) {
          setState(() => msg = 'Type your Name for Create');
          return;
        }
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailFromId(id), password: pass);
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'username': name,
          'userId': id,
          'searchName': name.toLowerCase(),
          'uid': cred.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      setState(() => msg = 'Error $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hamza Jani'), backgroundColor: Colors.green),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 55, backgroundImage: AssetImage('hamza_logo.png')),
            const SizedBox(height: 10),
            const Text('Hamza Jani', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (!isLogin) TextField(controller: _nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Your Name')),
            if (!isLogin) const SizedBox(height: 12),
            TextField(controller: _idCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Create User ID')),
            const SizedBox(height: 12),
            TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Password')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: submit, child: Text(isLogin ? 'LOGIN' : 'CREATE ACCOUNT')),
            TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? 'No account - Create one' : 'Have account - Login')),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> results = [];
  String myName = '';
  String myUid = '';
  StreamSubscription? _callSub;
  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser!.uid;
    _loadMe();
    _listenIncoming();
  }
  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }
  Future<void> _loadMe() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    if (doc.exists) setState(() => myName = doc.data()!['username'] ?? '');
  }
  void _listenIncoming() {
    _callSub = FirebaseFirestore.instance.collection('calls').where('calleeId', isEqualTo: myUid).where('status', isEqualTo: 'ringing').snapshots().listen((snap) {
      for (var doc in snap.docs) {
        final data = doc.data();
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text('${data['callerName']} is calling you'),
            content: const Text('Accept video call?'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await FirebaseFirestore.instance.collection('calls').doc(doc.id).update({'status': 'rejected'});
                },
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: doc.id, isCaller: false, otherName: data['callerName'] ?? '')));
                },
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      }
    });
  }
  Future<void> searchUsers() async {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return;
    final snap = await FirebaseFirestore.instance.collection('users').where('searchName', isGreaterThanOrEqualTo: q).where('searchName', isLessThanOrEqualTo: q + '\uf8ff').get();
    setState(() => results = snap.docs.map((d) => d.data()).where((u) => u['uid'] != myUid).toList());
  }
  Future<void> startCall(Map<String, dynamic> other) async {
    final callRef = FirebaseFirestore.instance.collection('calls').doc();
    await callRef.set({
      'callerId': myUid,
      'callerName': myName,
      'calleeId': other['uid'],
      'calleeName': other['username'],
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callRef.id, isCaller: true, otherName: other['username'] ?? '')));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.all(6), child: CircleAvatar(backgroundImage: AssetImage('hamza_logo.png'))),
        title: Text('Hi $myName'),
        backgroundColor: Colors.green,
        actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Search People by Name', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _searchCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Type Name to Search'))),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: searchUsers, child: const Text('SEARCH')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final u = results[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundImage: AssetImage('hamza_logo.png')),
                      title: Text(u['username'] ?? ''),
                      subtitle: Text('@${u['userId'] ?? ''}'),
                      trailing: ElevatedButton(onPressed: () => startCall(u), child: const Text('CALL')),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final String otherName;
  const CallScreen({super.key, required this.callId, required this.isCaller, required this.otherName});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String status = 'Connecting';
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  StreamSubscription? _callSub;
  StreamSubscription? _candSub;
  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _setupCall();
  }
  @override
  void dispose() {
    _callSub?.cancel();
    _candSub?.cancel();
    _pc?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
  Future<RTCPeerConnection> _createPC(String myRole) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          status = 'CONNECTED - Talk now';
        });
      }
    };
    pc.onConnectionState = (state) {
      setState(() => status = 'Connection $state');
    };
    pc.onIceCandidate = (cand) async {
      if (cand.candidate == null) return;
      await FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection(myRole == 'caller' ? 'callerCandidates' : 'calleeCandidates').add({
        'candidate': cand.candidate,
        'sdpMid': cand.sdpMid,
        'sdpMLineIndex': cand.sdpMLineIndex,
      });
    };
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
    _localRenderer.srcObject = _localStream;
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });
    return pc;
  }
  Future<void> _setupCall() async {
    await Permission.microphone.request();
    await Permission.camera.request();
    final callRef = FirebaseFirestore.instance.collection('calls').doc(widget.callId);
    if (widget.isCaller) {
      setState(() => status = 'Calling ${widget.otherName} - Waiting');
      _pc = await _createPC('caller');
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      final desc = await _pc!.getLocalDescription();
      await callRef.update({'offer': desc!.sdp, 'status': 'ringing'});
      _callSub = callRef.snapshots().listen((snap) async {
        final data = snap.data();
        if (data == null) return;
        if (data['answer'] != null && _pc!.getRemoteDescription() == null) {
          await _pc!.setRemoteDescription(RTCSessionDescription(data['answer'], 'answer'));
          setState(() => status = 'Connected - Talk now');
        }
        if (data['status'] == 'rejected') {
          setState(() => status = 'Call Rejected');
        }
      });
      _candSub = callRef.collection('calleeCandidates').snapshots().listen((snap) {
        for (var change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final d = change.doc.data()!;
            _pc!.addCandidate(RTCIceCandidate(d['candidate'], d['sdpMid'], d['sdpMLineIndex']));
          }
        }
      });
    } else {
      setState(() => status = 'Accepting call from ${widget.otherName}');
      _pc = await _createPC('callee');
      final snap = await callRef.get();
      final offerSdp = snap.data()!['offer'] as String;
      await _pc!.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      final desc = await _pc!.getLocalDescription();
      await callRef.update({'answer': desc!.sdp, 'status': 'connected'});
      _candSub = callRef.collection('callerCandidates').snapshots().listen((snap2) {
        for (var change in snap2.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final d = change.doc.data()!;
            _pc!.addCandidate(RTCIceCandidate(d['candidate'], d['sdpMid'], d['sdpMLineIndex']));
          }
        }
      });
    }
  }
  Future<void> _endCall() async {
    await FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({'status': 'ended'});
    if (mounted) Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Call ${widget.otherName}'), backgroundColor: Colors.green),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          Expanded(
            child: Row(
              children: [
                Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
                Expanded(child: RTCVideoView(_remoteRenderer)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: _endCall, child: const Text('END CALL')),
          ),
        ],
      ),
    );
  }
}
