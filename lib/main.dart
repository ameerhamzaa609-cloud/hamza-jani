import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) { print("Firebase init: $e"); }
  await [Permission.microphone, Permission.camera].request();
  runApp(HamzaApp());
}

class HamzaApp extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return MaterialApp(title: 'Hamza Jani', theme: ThemeData(primarySwatch: Colors.blue), home: AuthCheck());
  }
}

class AuthCheck extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snap.hasData) return HomeScreen();
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget { @override _LoginScreenState createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final userController = TextEditingController();
  final passController = TextEditingController();
  String error = ""; bool isLogin = true;
  Future<void> submit() async {
    setState(()=> error="Loading...");
    try {
      String email = "${userController.text.trim()}@hamzajani.com";
      String pass = passController.text.trim();
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
        await FirebaseFirestore.instance.collection("users").doc(FirebaseAuth.instance.currentUser!.uid).set({
          "username": userController.text.trim(), "uid": FirebaseAuth.instance.currentUser!.uid, "created": FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch(e){ setState(()=> error=e.message ?? e.code); }
    catch(e){ setState(()=> error=e.toString()); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Hamza Jani - ${isLogin ? "Login" : "Create Account"}")),
      body: Padding(padding: EdgeInsets.all(20), child: Column(children: [
        Icon(Icons.phone, size: 80, color: Colors.blue),
        SizedBox(height: 20),
        TextField(controller: userController, decoration: InputDecoration(labelText: "User ID", border: OutlineInputBorder())),
        SizedBox(height: 10),
        TextField(controller: passController, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
        SizedBox(height: 20),
        ElevatedButton(onPressed: submit, child: Text(isLogin ? "LOGIN" : "CREATE ACCOUNT")),
        TextButton(onPressed: ()=> setState((){ isLogin=!isLogin; error=""; }), child: Text(isLogin ? "Need account? Create" : "Have account? Login")),
        Text(error, style: TextStyle(color: Colors.red)),
      ])));
  }
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final searchController = TextEditingController();
  List<DocumentSnapshot> results = [];
  Future<void> search() async {
    var q = await FirebaseFirestore.instance.collection("users").where("username", isEqualTo: searchController.text.trim()).get();
    setState(()=> results=q.docs);
  }
  @override Widget build(BuildContext context) {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text("Hamza Jani"), actions: [IconButton(icon: Icon(Icons.logout), onPressed: ()=> FirebaseAuth.instance.signOut())]),
      body: _tab == 0 ? _buildDialTab(myUid) : CallHistoryScreen(myUid: myUid),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab, onTap: (i)=> setState(()=> _tab=i),
        items: [BottomNavigationBarItem(icon: Icon(Icons.call), label: "Dial"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "History")],
      ),
    );
  }
  Widget _buildDialTab(String myUid){
    return Padding(padding: EdgeInsets.all(16), child: Column(children: [
      TextField(controller: searchController, decoration: InputDecoration(labelText: "Search User ID", suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: search))),
      Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (c,i){
        var data = results[i].data() as Map<String,dynamic>;
        return ListTile(title: Text(data["username"] ?? ""), trailing: ElevatedButton(child: Text("CALL"), onPressed: (){
          String callId = "${myUid}_${data["uid"]}_${DateTime.now().millisecondsSinceEpoch}";
          Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: data["uid"], otherName: data["username"] ?? "")));
        }));
      })),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("calls").where("to", isEqualTo: myUid).where("status", isEqualTo: "calling").snapshots(),
        builder: (c,snap){
          if(!snap.hasData || snap.data!.docs.isEmpty) return SizedBox();
          var callDoc = snap.data!.docs.first;
          var callData = callDoc.data() as Map<String,dynamic>;
          return Card(color: Colors.green[100], child: ListTile(
            title: Text("Incoming Call"),
            subtitle: Text("From: ${callData["fromName"] ?? "User"}"),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(child: Text("Accept"), onPressed: (){
                Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callDoc.id, isCaller: false, otherUid: callData["from"], otherName: callData["fromName"] ?? "")));
              }),
              SizedBox(width: 8),
              ElevatedButton(child: Text("Reject"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
                await callDoc.reference.update({"status":"missed", "endTime": FieldValue.serverTimestamp()});
              }),
            ]),
          ));
        },
      ),
    ]));
  }
}

class CallHistoryScreen extends StatefulWidget {
  final String myUid; CallHistoryScreen({required this.myUid});
  @override _CallHistoryScreenState createState() => _CallHistoryScreenState();
}
class _CallHistoryScreenState extends State<CallHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override void initState(){ super.initState(); _tabCtrl = TabController(length: 4, vsync: this); }
  @override Widget build(BuildContext context){
    return Column(children: [
      TabBar(controller: _tabCtrl, labelColor: Colors.blue, tabs: [Tab(text: "All"), Tab(text: "Dialed"), Tab(text: "Received"), Tab(text: "Missed")]),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [
        _historyList("all"), _historyList("dialed"), _historyList("received"), _historyList("missed"),
      ])),
    ]);
  }
  Widget _historyList(String filter){
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("calls").orderBy("time", descending: true).limit(100).snapshots(),
      builder: (c, snap){
        if(!snap.hasData) return Center(child: CircularProgressIndicator());
        var docs = snap.data!.docs.where((d){
          var data = d.data() as Map<String,dynamic>;
          bool isMine = data["from"]==widget.myUid || data["to"]==widget.myUid;
          if(!isMine) return false;
          String type = "";
          if(data["from"]==widget.myUid) type="dialed";
          else if(data["status"]=="missed") type="missed";
          else type="received";
          if(filter=="all") return true;
          return type==filter;
        }).toList();
        if(docs.isEmpty) return Center(child: Text("No $filter calls yet"));
        return ListView.builder(itemCount: docs.length, itemBuilder: (c,i){
          var data = docs[i].data() as Map<String,dynamic>;
          bool isOutgoing = data["from"]==widget.myUid;
          String otherName = isOutgoing ? (data["toName"] ?? data["to"] ?? "") : (data["fromName"] ?? data["from"] ?? "");
          String status = data["status"] ?? "";
          IconData icon; Color color; String label;
          if(isOutgoing){ icon=Icons.call_made; color=Colors.green; label="Dialed"; }
          else if(status=="missed"){ icon=Icons.call_missed; color=Colors.red; label="Missed"; }
          else { icon=Icons.call_received; color=Colors.blue; label="Received"; }
          String timeStr = "";
          if(data["time"]!=null){ try{ var t=(data["time"] as Timestamp).toDate(); timeStr="${t.day}/${t.month} ${t.hour}:${t.minute.toString().padLeft(2,'0')}"; }catch(_){} }
          return ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            title: Text(otherName, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$label • $timeStr"),
            trailing: IconButton(icon: Icon(Icons.call, color: Colors.green), onPressed: (){
              String otherUid = isOutgoing ? data["to"] : data["from"];
              String callId = "${widget.myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}";
              Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName)));
            }),
          );
        });
      },
    );
  }
}

class CallScreen extends StatefulWidget {
  final String callId; final bool isCaller; final String otherUid; final String otherName;
  CallScreen({required this.callId, required this.isCaller, required this.otherUid, required this.otherName});
  @override _CallScreenState createState() => _CallScreenState();
}
class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  String status = "Connecting...";
  bool micOn = true; bool camOn = true;

  @override void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await [Permission.microphone, Permission.camera].request();
    _localStream = await navigator.mediaDevices.getUserMedia({"audio": true, "video": {"facingMode": "user"}});
    _localRenderer.srcObject = _localStream;
    setState((){});

    Map<String,dynamic> config = {"iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
      {"urls": "turn:openrelay.metered.ca:80", "username": "openrelayproject", "credential": "openrelayproject"},
      {"urls": "turn:openrelay.metered.ca:443", "username": "openrelayproject", "credential": "openrelayproject"},
      {"urls": "turn:openrelay.metered.ca:443?transport=tcp", "username": "openrelayproject", "credential": "openrelayproject"},
    ]};

    _pc = await createPeerConnection(config);

    _localStream!.getTracks().forEach((t){ _pc!.addTrack(t, _localStream!); });

    // FIXED: Remote video handling - both callbacks
    _pc!.onTrack = (RTCTrackEvent e){
      print("ON TRACK RECEIVED: ${e.track.kind}");
      if(e.streams.isNotEmpty){
        _remoteRenderer.srcObject = e.streams[0];
        setState(()=> status="Connected - ${widget.otherName}");
      }
    };
    _pc!.onAddStream = (MediaStream stream){
      print("ON ADD STREAM");
      _remoteRenderer.srcObject = stream;
      setState(()=> status="Connected - ${widget.otherName}");
    };

    _pc!.onIceCandidate = (c){
      if(c.candidate != null){
        FirebaseFirestore.instance.collection("calls").doc(widget.callId).collection(widget.isCaller ? "callerCandidates" : "calleeCandidates").add(c.toMap());
      }
    };

    var callRef = FirebaseFirestore.instance.collection("calls").doc(widget.callId);
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    String myName = "";
    var myDoc = await FirebaseFirestore.instance.collection("users").doc(myUid).get();
    if(myDoc.exists) myName = (myDoc.data() as Map<String,dynamic>)["username"] ?? "";

    if(widget.isCaller){
      await callRef.set({"from": myUid, "fromName": myName, "to": widget.otherUid, "toName": widget.otherName, "status": "calling", "time": FieldValue.serverTimestamp()});
      RTCSessionDescription offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await callRef.update({"offer": offer.toMap()});
      setState(()=> status="Calling ${widget.otherName}...");
      callRef.snapshots().listen((snap){
        var d = snap.data(); if(d==null) return;
        if(d["answer"] != null && _pc!.getRemoteDescription() == null){
          _pc!.setRemoteDescription(RTCSessionDescription(d["answer"]["sdp"], d["answer"]["type"]));
        }
        if(d["status"]=="rejected") setState(()=> status="Rejected");
        if(d["status"]=="missed") setState(()=> status="Missed");
        if(d["status"]=="ended") Navigator.pop(context);
      });
      callRef.collection("calleeCandidates").snapshots().listen((snap){
        for(var doc in snap.docChanges){ if(doc.type==DocumentChangeType.added){ var d=doc.doc.data(); _pc!.addCandidate(RTCIceCandidate(d!["candidate"], d["sdpMid"], d["sdpMLineIndex"])); } }
      });
    } else {
      var snap = await callRef.get();
      var data = snap.data() as Map<String,dynamic>;
      await _pc!.setRemoteDescription(RTCSessionDescription(data["offer"]["sdp"], data["offer"]["type"]));
      RTCSessionDescription answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await callRef.update({"answer": answer.toMap(), "status": "accepted"});
      setState(()=> status="Connected - ${widget.otherName}");
      callRef.collection("callerCandidates").snapshots().listen((snap){
        for(var doc in snap.docChanges){ if(doc.type==DocumentChangeType.added){ var d=doc.doc.data(); _pc!.addCandidate(RTCIceCandidate(d!["candidate"], d["sdpMid"], d["sdpMLineIndex"])); } }
      });
      callRef.snapshots().listen((s){ var d=s.data(); if(d!=null && d["status"]=="ended") Navigator.pop(context); });
    }
  }

  Future<void> _hangUp() async {
    var doc = await FirebaseFirestore.instance.collection("calls").doc(widget.callId).get();
    var data = doc.data();
    String newStatus = "ended";
    if(data!=null && data["status"]=="calling" && widget.isCaller){ newStatus="missed"; }
    await FirebaseFirestore.instance.collection("calls").doc(widget.callId).update({"status": newStatus, "endTime": FieldValue.serverTimestamp()});
    await _pc?.close(); await _localStream?.dispose();
    if(mounted) Navigator.pop(context);
  }

  @override void dispose(){ _localRenderer.dispose(); _remoteRenderer.dispose(); _pc?.close(); _localStream?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(status), backgroundColor: Colors.black),
      body: Stack(children: [
        // Remote video - FULL SCREEN
        Container(color: Colors.black, child: RTCVideoView(_remoteRenderer, mirror: false, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
        // If remote not yet connected, show message
        if(_remoteRenderer.srcObject == null)
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text("Waiting for ${widget.otherName} video...", style: TextStyle(color: Colors.white, fontSize: 16)),
          ])),
        // Local small video
        Positioned(top: 10, right: 10, width: 120, height: 160, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white)), child: RTCVideoView(_localRenderer, mirror: true))),
        Positioned(bottom: 20, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FloatingActionButton(backgroundColor: micOn?Colors.white:Colors.red, onPressed: (){ setState(()=> micOn=!micOn); _localStream?.getAudioTracks().forEach((t)=> t.enabled=micOn); }, child: Icon(micOn?Icons.mic:Icons.mic_off)),
          SizedBox(width: 16),
          FloatingActionButton(backgroundColor: Colors.red, onPressed: _hangUp, child: Icon(Icons.call_end)),
          SizedBox(width: 16),
          FloatingActionButton(backgroundColor: camOn?Colors.white:Colors.red, onPressed: (){ setState(()=> camOn=!camOn); _localStream?.getVideoTracks().forEach((t)=> t.enabled=camOn); }, child: Icon(camOn?Icons.videocam:Icons.videocam_off)),
        ])),
      ]),
    );
  }
}
