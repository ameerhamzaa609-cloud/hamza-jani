import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) { print("Firebase: $e"); }
  await [Permission.microphone, Permission.camera, Permission.contacts, Permission.photos].request();
  runApp(HamzaApp());
}

class HamzaApp extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return MaterialApp(title: 'Hamza Jani', theme: ThemeData(primarySwatch: Colors.deepPurple, scaffoldBackgroundColor: Color(0xFFF6F4FF), appBarTheme: AppBarTheme(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, elevation: 0), elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12))), cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2)), home: AuthCheck());
  }
}

class AuthCheck extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snap.hasData) return HomeScreen();
      return LoginScreen();
    });
  }
}

class LoginScreen extends StatefulWidget { @override _LoginScreenState createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final userController = TextEditingController(); final passController = TextEditingController(); String error = ""; bool isLogin = true;
  Future<void> submit() async {
    setState(()=> error="Loading...");
    try {
      String email = "${userController.text.trim()}@hamzajani.com"; String pass = passController.text.trim();
      if (isLogin) { await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass); }
      else { await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass); await FirebaseFirestore.instance.collection("users").doc(FirebaseAuth.instance.currentUser!.uid).set({"username": userController.text.trim(), "uid": FirebaseAuth.instance.currentUser!.uid, "created": FieldValue.serverTimestamp(), "online": true, "photoUrl": ""}); }
    } on FirebaseAuthException catch(e){ setState(()=> error=e.message ?? e.code); } catch(e){ setState(()=> error=e.toString()); }
  }
  Future<void> forgot() async { if(userController.text.trim().isEmpty){ setState(()=> error="Type User ID first"); return; } try { await FirebaseAuth.instance.sendPasswordResetEmail(email: "${userController.text.trim()}@hamzajani.com"); setState(()=> error="Reset link sent."); } catch(e){ setState(()=> error=e.toString()); } }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Hamza Jani - ${isLogin ? "Login" : "Create Account"}")),
      body: Padding(padding: EdgeInsets.all(20), child: Column(children: [
        CircleAvatar(radius: 50, backgroundColor: Colors.deepPurple[100], child: Icon(Icons.phone, size: 50, color: Colors.deepPurple)),
        SizedBox(height: 10), Text("Hamza Jani", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple)), SizedBox(height: 20),
        TextField(controller: userController, decoration: InputDecoration(labelText: "User ID", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white)),
        SizedBox(height: 10), TextField(controller: passController, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white), obscureText: true),
        SizedBox(height: 20), ElevatedButton(onPressed: submit, child: Text(isLogin ? "LOGIN" : "CREATE ACCOUNT")),
        TextButton(onPressed: ()=> setState((){ isLogin=!isLogin; error=""; }), child: Text(isLogin ? "Need account? Create" : "Have account? Login")),
        TextButton(onPressed: forgot, child: Text("Forgot Password?")), Text(error, style: TextStyle(color: Colors.red)),
      ])));
  }
}

class HomeScreen extends StatefulWidget { @override _HomeScreenState createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0; final searchController = TextEditingController(); List<DocumentSnapshot> results = []; String myPhoto = ""; String myName = ""; Set<String> blockedUids = {};
  @override void initState(){ super.initState(); _setOnline(true); _loadMe(); _loadBlocked(); }
  Future<void> _loadMe() async { String uid = FirebaseAuth.instance.currentUser!.uid; var doc = await FirebaseFirestore.instance.collection("users").doc(uid).get(); if(doc.exists){ var d = doc.data() as Map<String,dynamic>; setState(()=> {myPhoto = d["photoUrl"] ?? "", myName = d["username"] ?? ""}); } }
  Future<void> _loadBlocked() async { String uid = FirebaseAuth.instance.currentUser!.uid; var snap = await FirebaseFirestore.instance.collection("users").doc(uid).collection("blocked").get(); setState(()=> blockedUids = snap.docs.map((e)=> e.id).toSet()); }
  Future<void> _setOnline(bool v) async { try { await FirebaseFirestore.instance.collection("users").doc(FirebaseAuth.instance.currentUser!.uid).update({"online": v, "lastSeen": FieldValue.serverTimestamp()}); } catch(e){} }
  Future<void> search() async { var q = await FirebaseFirestore.instance.collection("users").where("username", isEqualTo: searchController.text.trim()).get(); setState(()=> results=q.docs); }
  Future<void> saveToPhonebook(String otherUid, String otherName) async { String myUid = FirebaseAuth.instance.currentUser!.uid; await FirebaseFirestore.instance.collection("users").doc(myUid).collection("phonebook").doc(otherUid).set({"uid": otherUid, "username": otherName, "savedAt": FieldValue.serverTimestamp()}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$otherName saved ✅"))); }
  Future<void> blockUser(String otherUid, String otherName) async { String myUid = FirebaseAuth.instance.currentUser!.uid; await FirebaseFirestore.instance.collection("users").doc(myUid).collection("blocked").doc(otherUid).set({"uid": otherUid, "username": otherName}); setState(()=> blockedUids.add(otherUid)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$otherName blocked 🚫"))); }
  Future<void> pickPhoto() async { final picker = ImagePicker(); final XFile? img = await picker.pickImage(source: ImageSource.gallery); if(img == null) return; String uid = FirebaseAuth.instance.currentUser!.uid; try { var ref = FirebaseStorage.instance.ref().child("profiles/$uid.jpg"); await ref.putFile(File(img.path)); String url = await ref.getDownloadURL(); await FirebaseFirestore.instance.collection("users").doc(uid).update({"photoUrl": url}); setState(()=> myPhoto = url); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Photo updated ✅"))); } catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e"))); } }
  String getChatId(String a, String b){ return a.compareTo(b) < 0 ? "${a}_$b" : "${b}_$a"; }
  Widget avatar(String photo, String name, {double r=20}){ if(photo.isNotEmpty) return CircleAvatar(radius: r, backgroundImage: NetworkImage(photo)); return CircleAvatar(radius: r, backgroundColor: Colors.deepPurple[100], child: Text(name.isNotEmpty ? name.substring(0,1).toUpperCase() : "?", style: TextStyle(color: Colors.deepPurple))); }
  Widget onlineDot(bool online){ return Container(width: 12, height: 12, decoration: BoxDecoration(color: online ? Colors.green : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))); }
  @override Widget build(BuildContext context) {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text("Hamza Jani"), actions: [GestureDetector(onTap: pickPhoto, child: Padding(padding: EdgeInsets.only(right: 8), child: Stack(children: [avatar(myPhoto, myName, r: 18), Positioned(bottom: 0, right: 0, child: Icon(Icons.camera_alt, size: 12, color: Colors.white))]))), IconButton(icon: Icon(Icons.share), onPressed: (){ Share.share("Download Hamza Jani App! My User ID: $myName"); }), IconButton(icon: Icon(Icons.logout), onPressed: () async { await _setOnline(false); await FirebaseAuth.instance.signOut(); })]),
      body: _tab==0 ? _buildOnlineTab(myUid) : _tab==1 ? GroupScreen(myUid: myUid) : _tab==2 ? MessagesListScreen(myUid: myUid) : _tab==3 ? PhonebookScreen(myUid: myUid) : CallHistoryScreen(myUid: myUid),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _tab, onTap: (i)=> setState(()=> _tab=i), type: BottomNavigationBarType.fixed, selectedItemColor: Colors.deepPurple, items: [BottomNavigationBarItem(icon: Icon(Icons.wifi), label: "Online"), BottomNavigationBarItem(icon: Icon(Icons.group), label: "Group"), BottomNavigationBarItem(icon: Icon(Icons.message), label: "Messages"), BottomNavigationBarItem(icon: Icon(Icons.contacts), label: "Phonebook"), BottomNavigationBarItem(icon: Icon(Icons.history), label: "History")]),
    );
  }
  Widget _buildOnlineTab(String myUid){
    return Padding(padding: EdgeInsets.all(16), child: Column(children: [
      Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(children: [CircleAvatar(backgroundColor: Colors.deepPurple[100], child: Icon(Icons.wifi, color: Colors.deepPurple)), SizedBox(width: 8), Expanded(child: Text("Hello $myName 👋\nOnline Call - Audio / Video"))])),
      SizedBox(height: 10), TextField(controller: searchController, decoration: InputDecoration(labelText: "Search User ID", suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white)),
      Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (c,i){
        var data = results[i].data() as Map<String,dynamic>; String otherUid = data["uid"]; String otherName = data["username"] ?? ""; String photo = data["photoUrl"] ?? ""; bool online = data["online"] == true; if(blockedUids.contains(otherUid)) return SizedBox();
        return Card(child: ListTile(leading: Stack(children: [avatar(photo, otherName), Positioned(bottom: 0, right: 0, child: onlineDot(online))]), title: Text(otherName, style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(online ? "● Online" : "○ Offline"),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(Icons.bookmark_add, color: Colors.orange), onPressed: ()=> saveToPhonebook(otherUid, otherName)),
            IconButton(icon: Icon(Icons.block, color: Colors.red), onPressed: ()=> blockUser(otherUid, otherName)),
            IconButton(icon: Icon(Icons.message, color: Colors.blue), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: getChatId(myUid, otherUid), otherUid: otherUid, otherName: otherName))); }),
            IconButton(icon: Icon(Icons.call, color: Colors.green), onPressed: (){ String callId = "${myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}"; Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName, audioOnly: true))); }),
            IconButton(icon: Icon(Icons.videocam, color: Colors.purple), onPressed: (){ String callId = "${myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}"; Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName, audioOnly: false))); }),
          ]),
        ));
      })),
      StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection("calls").where("to", isEqualTo: myUid).where("status", isEqualTo: "calling").snapshots(), builder: (c,snap){ if(!snap.hasData || snap.data!.docs.isEmpty) return SizedBox(); var callDoc = snap.data!.docs.first; var callData = callDoc.data() as Map<String,dynamic>; if(blockedUids.contains(callData["from"])) return SizedBox(); bool audioOnly = callData["audioOnly"] == true; return Card(color: Colors.green[100], child: ListTile(title: Text("Incoming ${audioOnly ? "Audio" : "Video"} Call"), subtitle: Text("From: ${callData["fromName"] ?? "User"}"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [ElevatedButton(child: Text("Accept"), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callDoc.id, isCaller: false, otherUid: callData["from"], otherName: callData["fromName"] ?? "", audioOnly: audioOnly))); }), SizedBox(width: 8), ElevatedButton(child: Text("Reject"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await callDoc.reference.update({"status":"missed"}); })]))); }),
    ]));
  }
}

class GroupScreen extends StatefulWidget { final String myUid; GroupScreen({required this.myUid}); @override _GroupScreenState createState() => _GroupScreenState(); }
class _GroupScreenState extends State<GroupScreen> {
  final groupNameCtrl = TextEditingController();
  Future<void> createGroup() async { if(groupNameCtrl.text.trim().isEmpty) return; String myName = ""; var myDoc = await FirebaseFirestore.instance.collection("users").doc(widget.myUid).get(); if(myDoc.exists) myName = (myDoc.data() as Map<String,dynamic>)["username"] ?? ""; String gid = "group_${DateTime.now().millisecondsSinceEpoch}"; await FirebaseFirestore.instance.collection("group_calls").doc(gid).set({"name": groupNameCtrl.text.trim(), "createdBy": widget.myUid, "createdByName": myName, "createdAt": FieldValue.serverTimestamp(), "members": [widget.myUid]}); groupNameCtrl.clear(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Group created ✅"))); }
  @override Widget build(BuildContext context){ return Padding(padding: EdgeInsets.all(16), child: Column(children: [TextField(controller: groupNameCtrl, decoration: InputDecoration(labelText: "Group Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white)), SizedBox(height: 10), ElevatedButton.icon(onPressed: createGroup, icon: Icon(Icons.add), label: Text("CREATE GROUP")), SizedBox(height: 10), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection("group_calls").orderBy("createdAt", descending: true).snapshots(), builder: (c, snap){ if(!snap.hasData) return Center(child: CircularProgressIndicator()); if(snap.data!.docs.isEmpty) return Center(child: Text("No groups yet.")); return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){ var d = snap.data!.docs[i].data() as Map<String,dynamic>; return Card(child: ListTile(leading: CircleAvatar(backgroundColor: Colors.purple[100], child: Icon(Icons.group, color: Colors.purple)), title: Text(d["name"] ?? "Group"), subtitle: Text("By ${d["createdByName"] ?? ""}"), trailing: ElevatedButton(child: Text("JOIN"), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => GroupCallScreen(groupId: snap.data!.docs[i].id, groupName: d["name"] ?? "Group", myUid: widget.myUid))); }))); }); })), ])); }
}

class GroupCallScreen extends StatefulWidget { final String groupId; final String groupName; final String myUid; GroupCallScreen({required this.groupId, required this.groupName, required this.myUid}); @override _GroupCallScreenState createState() => _GroupCallScreenState(); }
class _GroupCallScreenState extends State<GroupCallScreen> {
  MediaStream? _localStream; final _localRenderer = RTCVideoRenderer(); Map<String, RTCVideoRenderer> remoteRenderers = {}; Map<String, RTCPeerConnection> pcs = {}; Map<String, List<RTCIceCandidate>> pending = {};
  bool micOn = true; bool camOn = true; bool speakerOn = true; String myName = ""; String err = "";
  @override void initState(){ super.initState(); _initSafe(); }
  Future<void> _initSafe() async { try { await _init(); } catch(e){ if(mounted) setState(()=> err=e.toString()); } }
  Future<void> _init() async {
    await _localRenderer.initialize(); await [Permission.microphone, Permission.camera].request(); await Helper.setSpeakerphoneOn(true);
    var myDoc = await FirebaseFirestore.instance.collection("users").doc(widget.myUid).get(); if(myDoc.exists) myName = (myDoc.data() as Map<String,dynamic>)["username"] ?? "";
    _localStream = await navigator.mediaDevices.getUserMedia({"audio": {"echoCancellation": true, "noiseSuppression": true, "autoGainControl": true}, "video": {"facingMode": "user"}});
    _localStream!.getAudioTracks().forEach((t){ t.enabled = true; }); _localStream!.getVideoTracks().forEach((t){ t.enabled = true; });
    _localRenderer.srcObject = _localStream; setState((){});
    await FirebaseFirestore.instance.collection("group_calls").doc(widget.groupId).collection("members").doc(widget.myUid).set({"uid": widget.myUid, "name": myName, "joinedAt": FieldValue.serverTimestamp()});
    FirebaseFirestore.instance.collection("group_calls").doc(widget.groupId).collection("members").snapshots().listen((snap){ for(var doc in snap.docChanges){ if(doc.type == DocumentChangeType.added){ String peerUid = doc.doc.id; if(peerUid != widget.myUid && !pcs.containsKey(peerUid)) _createPeerFor(peerUid); } if(doc.type == DocumentChangeType.removed){ _removePeer(doc.doc.id); } } });
    FirebaseFirestore.instance.collection("group_calls").doc(widget.groupId).collection("signals").where("to", isEqualTo: widget.myUid).snapshots().listen((snap){ for(var doc in snap.docChanges){ if(doc.type == DocumentChangeType.added) _handleSignal(doc.doc.data() as Map<String,dynamic>); } });
  }
  Future<void> _createPeerFor(String peerUid) async {
    try {
      var renderer = RTCVideoRenderer(); await renderer.initialize(); if(mounted) setState(()=> remoteRenderers[peerUid] = renderer);
      Map<String,dynamic> config = {"iceServers": [{"urls": "stun:stun.l.google.com:19302"}, {"urls": "turn:openrelay.metered.ca:80", "username": "openrelayproject", "credential": "openrelayproject"}, {"urls": "turn:openrelay.metered.ca:443", "username": "openrelayproject", "credential": "openrelayproject"}]};
      RTCPeerConnection pc = await createPeerConnection(config); pcs[peerUid] = pc; pending[peerUid] = [];
      for(var t in _localStream!.getTracks()) pc.addTrack(t, _localStream!);
      pc.onTrack = (e){ if(e.streams.isNotEmpty){ e.streams[0].getAudioTracks().forEach((t)=> t.enabled = true); e.streams[0].getVideoTracks().forEach((t)=> t.enabled = true); renderer.srcObject = e.streams[0]; setState((){}); } };
      pc.onIceCandidate = (c){ if(c.candidate != null){ FirebaseFirestore.instance.collection("group_calls").doc(widget.groupId).collection("signals").add({"from": widget.myUid, "to": peerUid, "type": "candidate", "candidate": c.toMap(), "time": FieldValue.serverTimestamp()}); } };
      if(widget.myUid.compareTo(peerUid) < 0){ RTCSessionDescription offer = await pc.createOffer(); await pc.setLocalDescription(offer); await FirebaseFirestore.instance.collection("group_calls").doc(widget.groupId).collection("signals").add({"from": widget.myUid, "to": peerUid, "type": "offer", "sdp": offer.sdp, "sdpType": offer.type, "time": FieldValue.serverTimestamp()}); }
    } catch(e){ if(mounted) setState(()=> err=e.toString()); }
  }
  Future<void> _handleSignal(Map<String,dynamic> data) async { try { String from = data["from"]; String type = data["type"]; if(!pcs.containsKey(from)) await _createPeerFor(from); var pc = pcs[from]!; if(type == "offer"){ await pc.setRemoteDescription(RTCSessionDescription(data["sdp"], data["sdpType"])); for(var cand in pending[from]!) await pc.addCandidate(cand); pending[from]!.clear(); RTCSessionDescription ans = await pc.createAnswer(); await pc.setLocalDescription(ans); await FirebaseFirestore.instance.collection("group_calls").doc(widget.groupId).collection("signals").add({"from": widget.myUid, "to": from, "type": "answer", "sdp": ans.sdp, "sdpType": ans.type, "time": FieldValue.serverTimestamp()}); } else if(type == "answer"){ if(pc.getRemoteDescription() == null){ await pc.setRemoteDescription(RTCSessionDescription(data["sdp"], data["sdpType"])); for(var cand in pending[from]!) await pc.addCandidate(cand); pending[from]!.clear(); } } else if(type == "candidate"){ var c = data["candidate"]; var cand = RTCIceCandidate(c["candidate"], c["sdpMid"], c["sdpMLineIndex"]); if(pc.getRemoteDescription() == null){ pending[from]!.add(cand); } else { await pc.addCandidate(cand); } } } catch(e){} }
  Future<void> _removePeer(String uid) async { await pcs[uid]?.close(); pcs.remove(uid); remoteRenderers[uid]?.dispose(); setState(()=> remoteRenderers.remove(uid)); }
  Future<void> _leave() async { try { await FirebaseFirestore.instance.collection("group_calls").doc(widget.groupId).collection("members").doc(widget.myUid).delete(); } catch(e){} for(var pc in pcs.values) await pc.close(); await _localStream?.dispose(); if(mounted) Navigator.pop(context); }
  @override void dispose(){ _localRenderer.dispose(); for(var r in remoteRenderers.values) r.dispose(); for(var pc in pcs.values) pc.close(); _localStream?.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    if(err.isNotEmpty) return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: Text("Group Error")), body: Padding(padding: EdgeInsets.all(20), child: Column(children: [Icon(Icons.error, color: Colors.red, size: 60), SizedBox(height: 10), Text(err, style: TextStyle(color: Colors.red)), SizedBox(height: 20), ElevatedButton(onPressed: ()=> Navigator.pop(context), child: Text("GO BACK"))])));
    List<Widget> videos = [Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white)), child: Stack(children: [RTCVideoView(_localRenderer, mirror: true), Positioned(bottom: 4, left: 4, child: Container(color: Colors.black54, padding: EdgeInsets.all(4), child: Text("You - $myName", style: TextStyle(color: Colors.white))))])))];
    remoteRenderers.forEach((uid, renderer){ videos.add(Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white)), child: RTCVideoView(renderer)))); });
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: Text("Group: ${widget.groupName} (${remoteRenderers.length + 1})"), backgroundColor: Colors.black),
      body: Column(children: [Expanded(child: GridView.count(crossAxisCount: 2, children: videos)), Container(color: Colors.black, padding: EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [FloatingActionButton(backgroundColor: micOn?Colors.white:Colors.red, mini: true, onPressed: (){ setState(()=> micOn=!micOn); _localStream?.getAudioTracks().forEach((t)=> t.enabled=micOn); }, child: Icon(micOn?Icons.mic:Icons.mic_off, size: 20)), SizedBox(width: 8), FloatingActionButton(backgroundColor: speakerOn?Colors.white:Colors.red, mini: true, onPressed: () async { setState(()=> speakerOn=!speakerOn); await Helper.setSpeakerphoneOn(speakerOn); }, child: Icon(speakerOn?Icons.volume_up:Icons.volume_off, size: 20)), SizedBox(width: 8), FloatingActionButton(backgroundColor: Colors.red, mini: true, onPressed: _leave, child: Icon(Icons.call_end, size: 20)), SizedBox(width: 8), FloatingActionButton(backgroundColor: camOn?Colors.white:Colors.red, mini: true, onPressed: (){ setState(()=> camOn=!camOn); _localStream?.getVideoTracks().forEach((t)=> t.enabled=camOn); }, child: Icon(camOn?Icons.videocam:Icons.videocam_off, size: 20)), SizedBox(width: 8), FloatingActionButton(backgroundColor: Colors.white, mini: true, onPressed: () async { if(_localStream!.getVideoTracks().isNotEmpty) await Helper.switchCamera(_localStream!.getVideoTracks()[0]); }, child: Icon(Icons.switch_camera, size: 20)) ])), ]), );
  }
}

class MessagesListScreen extends StatefulWidget { final String myUid; MessagesListScreen({required this.myUid}); @override _MessagesListScreenState createState() => _MessagesListScreenState(); }
class _MessagesListScreenState extends State<MessagesListScreen> {
  final searchCtrl = TextEditingController(); List<DocumentSnapshot> results = [];
  String getChatId(String a, String b){ return a.compareTo(b) < 0 ? "${a}_$b" : "${b}_$a"; }
  Future<void> search() async { var q = await FirebaseFirestore.instance.collection("users").where("username", isEqualTo: searchCtrl.text.trim()).get(); setState(()=> results=q.docs); }
  @override Widget build(BuildContext context){ return Padding(padding: EdgeInsets.all(16), child: Column(children: [TextField(controller: searchCtrl, decoration: InputDecoration(labelText: "Search User to Message", suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white)), SizedBox(height: 10), if(results.isNotEmpty) ...results.map((doc){ var d = doc.data() as Map<String,dynamic>; return Card(child: ListTile(title: Text(d["username"] ?? ""), trailing: Icon(Icons.message), onTap: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: getChatId(widget.myUid, d["uid"]), otherUid: d["uid"], otherName: d["username"] ?? ""))); })); }), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection("chats").where("members", arrayContains: widget.myUid).orderBy("lastTime", descending: true).snapshots(), builder: (c, snap){ if(!snap.hasData) return Center(child: CircularProgressIndicator()); if(snap.data!.docs.isEmpty) return Center(child: Text("No messages yet.")); return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){ var d = snap.data!.docs[i].data() as Map<String,dynamic>; String otherName = d["otherName_${widget.myUid}"] ?? "User"; List members = d["members"] ?? []; String otherUid = members.firstWhere((e)=> e != widget.myUid, orElse: ()=> ""); return Card(child: ListTile(leading: CircleAvatar(child: Text(otherName.isNotEmpty ? otherName.substring(0,1).toUpperCase() : "?")), title: Text(otherName), subtitle: Text(d["lastMessage"] ?? ""), onTap: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: snap.data!.docs[i].id, otherUid: otherUid, otherName: otherName))); })); }); })), ])); }
}

class ChatScreen extends StatefulWidget { final String chatId; final String otherUid; final String otherName; ChatScreen({required this.chatId, required this.otherUid, required this.otherName}); @override _ChatScreenState createState() => _ChatScreenState(); }
class _ChatScreenState extends State<ChatScreen> {
  final msgCtrl = TextEditingController();
  Future<void> send() async { if(msgCtrl.text.trim().isEmpty) return; String myUid = FirebaseAuth.instance.currentUser!.uid; String myName = ""; var myDoc = await FirebaseFirestore.instance.collection("users").doc(myUid).get(); if(myDoc.exists) myName = (myDoc.data() as Map<String,dynamic>)["username"] ?? ""; await FirebaseFirestore.instance.collection("chats").doc(widget.chatId).set({"members": [myUid, widget.otherUid], "lastMessage": msgCtrl.text.trim(), "lastTime": FieldValue.serverTimestamp(), "otherName_${myUid}": widget.otherName, "otherName_${widget.otherUid}": myName}, SetOptions(merge: true)); await FirebaseFirestore.instance.collection("chats").doc(widget.chatId).collection("messages").add({"text": msgCtrl.text.trim(), "from": myUid, "fromName": myName, "time": FieldValue.serverTimestamp()}); msgCtrl.clear(); }
  @override Widget build(BuildContext context){ String myUid = FirebaseAuth.instance.currentUser!.uid; return Scaffold(appBar: AppBar(title: Text(widget.otherName)), body: Column(children: [Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection("chats").doc(widget.chatId).collection("messages").orderBy("time", descending: false).snapshots(), builder: (c, snap){ if(!snap.hasData) return Center(child: CircularProgressIndicator()); return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){ var d = snap.data!.docs[i].data() as Map<String,dynamic>; bool isMe = d["from"] == myUid; return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: EdgeInsets.all(6), padding: EdgeInsets.all(10), decoration: BoxDecoration(color: isMe ? Colors.deepPurple[100] : Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Text(d["text"] ?? ""))); }); })), Padding(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: msgCtrl, decoration: InputDecoration(hintText: "Type message...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))), SizedBox(width: 8), IconButton(icon: Icon(Icons.send, color: Colors.deepPurple, size: 30), onPressed: send)])), ])); }
}

class PhonebookScreen extends StatefulWidget { final String myUid; PhonebookScreen({required this.myUid}); @override _PhonebookScreenState createState() => _PhonebookScreenState(); }
class _PhonebookScreenState extends State<PhonebookScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl; List<Contact> phoneContacts = []; List<Contact> filtered = []; bool loadingContacts = true; String contactError = ""; final searchCtrl = TextEditingController();
  @override void initState(){ super.initState(); _tabCtrl = TabController(length: 2, vsync: this); _loadPhoneContacts(); }
  Future<void> _loadPhoneContacts() async { try { bool perm = await FlutterContacts.requestPermission(readonly: true); if(!perm){ setState(()=> {loadingContacts=false, contactError="Contacts permission denied."}); return; } List<Contact> all = await FlutterContacts.getContacts(withProperties: true, withPhoto: false); all.sort((a,b)=> a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())); setState(()=> {phoneContacts=all, filtered=all, loadingContacts=false}); } catch(e){ setState(()=> {loadingContacts=false, contactError=e.toString()}); } }
  void _filter(String q){ setState(()=> filtered = q.isEmpty ? phoneContacts : phoneContacts.where((c)=> c.displayName.toLowerCase().contains(q.toLowerCase())).toList()); }
  String getChatId(String a, String b){ return a.compareTo(b) < 0 ? "${a}_$b" : "${b}_$a"; }
  @override Widget build(BuildContext context){ return Column(children: [TabBar(controller: _tabCtrl, labelColor: Colors.deepPurple, tabs: [Tab(text: "Phone Contacts"), Tab(text: "Hamza Saved")]), Expanded(child: TabBarView(controller: _tabCtrl, children: [_phoneContactsList(), _hamzaSavedList()])), ]); }
  Widget _phoneContactsList(){ if(loadingContacts) return Center(child: CircularProgressIndicator()); if(contactError.isNotEmpty) return Center(child: Text(contactError)); return Column(children: [Padding(padding: EdgeInsets.all(10), child: TextField(controller: searchCtrl, onChanged: _filter, decoration: InputDecoration(labelText: "Search phone contacts...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.white))), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Row(children: [Icon(Icons.contacts, color: Colors.green), SizedBox(width: 8), Text("${filtered.length} contacts"), Spacer(), TextButton.icon(onPressed: (){ Share.share("Download Hamza Jani App!"); }, icon: Icon(Icons.share), label: Text("Invite All"))])), Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (c,i){ Contact contact = filtered[i]; String phone = contact.phones.isNotEmpty ? contact.phones.first.number : ""; String name = contact.displayName.isNotEmpty ? contact.displayName : "Unknown"; return Card(child: ListTile(leading: CircleAvatar(backgroundColor: Colors.green[100], child: Text(name.isNotEmpty ? name.substring(0,1).toUpperCase() : "?")), title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(phone.isNotEmpty ? phone : "No number"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.share, color: Colors.orange), onPressed: (){ Share.share("Hi $name, download Hamza Jani App!"); }), Icon(Icons.search, color: Colors.blue)]), onTap: () async { var q = await FirebaseFirestore.instance.collection("users").where("username", isEqualTo: name.trim()).get(); if(q.docs.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name is not on Hamza yet."))); } else { var data = q.docs.first.data() as Map<String,dynamic>; Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: getChatId(widget.myUid, data["uid"]), otherUid: data["uid"], otherName: data["username"] ?? name))); } })); })), ]); }
  Widget _hamzaSavedList(){ return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection("users").doc(widget.myUid).collection("phonebook").orderBy("username").snapshots(), builder: (c, snap){ if(!snap.hasData) return Center(child: CircularProgressIndicator()); if(snap.data!.docs.isEmpty) return Center(child: Text("No saved users yet.")); return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){ var data = snap.data!.docs[i].data() as Map<String,dynamic>; String otherName = data["username"] ?? ""; String otherUid = data["uid"] ?? ""; return Card(child: ListTile(leading: CircleAvatar(child: Text(otherName.isNotEmpty ? otherName.substring(0,1).toUpperCase() : "?")), title: Text(otherName, style: TextStyle(fontWeight: FontWeight.bold)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.message, color: Colors.blue), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: getChatId(widget.myUid, otherUid), otherUid: otherUid, otherName: otherName))); }), IconButton(icon: Icon(Icons.call, color: Colors.green), onPressed: (){ String callId = "${widget.myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}"; Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName, audioOnly: true))); }), IconButton(icon: Icon(Icons.videocam, color: Colors.purple), onPressed: (){ String callId = "${widget.myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}"; Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName, audioOnly: false))); }), IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection("users").doc(widget.myUid).collection("phonebook").doc(otherUid).delete(); })]))); }); }); }
}

class CallHistoryScreen extends StatefulWidget { final String myUid; CallHistoryScreen({required this.myUid}); @override _CallHistoryScreenState createState() => _CallHistoryScreenState(); }
class _CallHistoryScreenState extends State<CallHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl; @override void initState(){ super.initState(); _tabCtrl = TabController(length: 4, vsync: this); }
  @override Widget build(BuildContext context){ return Column(children: [TabBar(controller: _tabCtrl, labelColor: Colors.deepPurple, tabs: [Tab(text: "All"), Tab(text: "Dialed"), Tab(text: "Received"), Tab(text: "Missed")]), Expanded(child: TabBarView(controller: _tabCtrl, children: [_historyList("all"), _historyList("dialed"), _historyList("received"), _historyList("missed")])), ]); }
  Widget _historyList(String filter){ return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection("calls").orderBy("time", descending: true).limit(100).snapshots(), builder: (c, snap){ if(!snap.hasData) return Center(child: CircularProgressIndicator()); var docs = snap.data!.docs.where((d){ var data = d.data() as Map<String,dynamic>; bool isMine = data["from"]==widget.myUid || data["to"]==widget.myUid; if(!isMine) return false; String type = ""; if(data["from"]==widget.myUid) type="dialed"; else if(data["status"]=="missed") type="missed"; else type="received"; if(filter=="all") return true; return type==filter; }).toList(); if(docs.isEmpty) return Center(child: Text("No $filter calls yet")); return ListView.builder(itemCount: docs.length, itemBuilder: (c,i){ var data = docs[i].data() as Map<String,dynamic>; bool isOutgoing = data["from"]==widget.myUid; String otherName = isOutgoing ? (data["toName"] ?? "") : (data["fromName"] ?? ""); String status = data["status"] ?? ""; IconData icon; Color color; String label; if(isOutgoing){ icon=Icons.call_made; color=Colors.green; label="Dialed"; } else if(status=="missed"){ icon=Icons.call_missed; color=Colors.red; label="Missed"; } else { icon=Icons.call_received; color=Colors.blue; label="Received"; } return ListTile(leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)), title: Text(otherName, style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(label), trailing: IconButton(icon: Icon(Icons.call, color: Colors.green), onPressed: (){ String otherUid = isOutgoing ? data["to"] : data["from"]; String callId = "${widget.myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}"; Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName, audioOnly: false))); })); }); }); }
}

// ===== WHITE PAGE FIXED - CALL SCREEN WITH ERROR SHOW =====
class CallScreen extends StatefulWidget {
  final String callId; final bool isCaller; final String otherUid; final String otherName; final bool audioOnly;
  CallScreen({required this.callId, required this.isCaller, required this.otherUid, required this.otherName, required this.audioOnly});
  @override _CallScreenState createState() => _CallScreenState();
}
class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _pc; MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer(); final _remoteRenderer = RTCVideoRenderer();
  String status = "Connecting..."; String errorMsg = ""; bool micOn = true; bool camOn = true; bool speakerOn = true; late bool audioOnly;
  List<RTCIceCandidate> _pending = []; bool _remoteDescSet = false; bool _remoteVideoGot = false; bool _answered = false;
  @override void initState() { super.initState(); audioOnly = widget.audioOnly; camOn = !audioOnly; _initSafe(); }
  Future<void> _initSafe() async { try { await _init(); } catch(e){ if(mounted) setState(()=> {status="Error", errorMsg=e.toString()}); } }
  Future<void> _addCandidate(RTCIceCandidate cand) async { if (!_remoteDescSet) { _pending.add(cand); return; } try { await _pc?.addCandidate(cand); } catch(e){} }
  Future<void> _flush() async { for(var c in _pending){ try { await _pc?.addCandidate(c); } catch(e){} } _pending.clear(); }
  Future<void> _forceAudio() async { try { await Helper.setSpeakerphoneOn(true); } catch(e){} _localStream?.getAudioTracks().forEach((t){ t.enabled = true; }); if(_remoteRenderer.srcObject != null){ try { (_remoteRenderer.srcObject as MediaStream).getAudioTracks().forEach((t){ t.enabled = true; }); } catch(e){} } }
  Future<void> _init() async {
    if(mounted) setState(()=> status="Starting camera + mic...");
    try { await _localRenderer.initialize(); } catch(e){ print("local renderer: $e"); }
    try { await _remoteRenderer.initialize(); } catch(e){ print("remote renderer: $e"); }
    var micStatus = await Permission.microphone.request();
    var camStatus = await Permission.camera.request();
    if(micStatus.isDenied){ if(mounted) setState(()=> errorMsg="Mic permission DENIED. Go to Settings > Apps > Hamza Jani > Permissions > Microphone > Allow"); return; }
    await Helper.setSpeakerphoneOn(true);
    // Get media - if this fails, show error, NOT white page
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({"audio": {"echoCancellation": true, "noiseSuppression": true, "autoGainControl": true}, "video": audioOnly ? false : {"facingMode": "user", "width": 640, "height": 480}});
    } catch(e){
      if(mounted) setState(()=> errorMsg="Camera/Mic failed: $e\n\nFix: Settings > Apps > Hamza Jani > Permissions > Allow Camera + Microphone, then close app and open again.");
      return;
    }
    _localStream!.getAudioTracks().forEach((t){ t.enabled = true; });
    _localStream!.getVideoTracks().forEach((t){ t.enabled = true; });
    if(!audioOnly) _localRenderer.srcObject = _localStream;
    if(mounted) setState(()=> status = "Camera ready, connecting to ${widget.otherName}...");
    Map<String,dynamic> config = {"iceServers": [{"urls": "stun:stun.l.google.com:19302"}, {"urls": "stun:stun1.l.google.com:19302"}, {"urls": "turn:openrelay.metered.ca:80", "username": "openrelayproject", "credential": "openrelayproject"}, {"urls": "turn:openrelay.metered.ca:443", "username": "openrelayproject", "credential": "openrelayproject"}, {"urls": "turn:openrelay.metered.ca:443?transport=tcp", "username": "openrelayproject", "credential": "openrelayproject"}]};
    _pc = await createPeerConnection(config);
    for(var track in _localStream!.getTracks()){ _pc!.addTrack(track, _localStream!); }
    _pc!.onTrack = (e){ if(e.streams.isNotEmpty){ e.streams[0].getAudioTracks().forEach((t){ t.enabled = true; }); e.streams[0].getVideoTracks().forEach((t){ t.enabled = true; }); _remoteRenderer.srcObject = e.streams[0]; _forceAudio(); if(mounted) setState(()=> {status="Connected - ${widget.otherName}", _remoteVideoGot=true}); } };
    _pc!.onAddStream = (s){ s.getAudioTracks().forEach((t)=> t.enabled = true); s.getVideoTracks().forEach((t)=> t.enabled = true); _remoteRenderer.srcObject = s; _forceAudio(); if(mounted) setState(()=> {status="Connected - ${widget.otherName}", _remoteVideoGot=true}); };
    _pc!.onConnectionState = (state){ if(state == RTCPeerConnectionState.RTCPeerConnectionStateConnected){ _forceAudio(); if(mounted) setState(()=> status="Connected - ${widget.otherName}"); } };
    _pc!.onIceCandidate = (c){ if(c.candidate != null){ try { FirebaseFirestore.instance.collection("calls").doc(widget.callId).collection(widget.isCaller ? "callerCandidates" : "calleeCandidates").add(c.toMap()); } catch(e){} } };
    var callRef = FirebaseFirestore.instance.collection("calls").doc(widget.callId);
    String myUid = FirebaseAuth.instance.currentUser!.uid; String myName = "";
    var myDoc = await FirebaseFirestore.instance.collection("users").doc(myUid).get(); if(myDoc.exists) myName = (myDoc.data() as Map<String,dynamic>)["username"] ?? "";
    if(widget.isCaller){
      await callRef.set({"from": myUid, "fromName": myName, "to": widget.otherUid, "toName": widget.otherName, "status": "calling", "audioOnly": audioOnly, "time": FieldValue.serverTimestamp()});
      RTCSessionDescription offer = await _pc!.createOffer(); await _pc!.setLocalDescription(offer); await callRef.update({"offer": offer.toMap()});
      if(mounted) setState(()=> status="Calling ${widget.otherName}... ${audioOnly ? "(Audio)" : "(Video)"}");
      callRef.snapshots().listen((snap) async { var d=snap.data(); if(d==null) return; if(d["answer"]!=null && !_remoteDescSet){ try { await _pc!.setRemoteDescription(RTCSessionDescription(d["answer"]["sdp"], d["answer"]["type"])); _remoteDescSet = true; await _flush(); _forceAudio(); if(mounted) setState(()=> status="Answer received - Connecting audio + video..."); } catch(e){} } if(d["status"]=="ended" && mounted) Navigator.pop(context); });
      callRef.collection("calleeCandidates").snapshots().listen((snap){ for(var doc in snap.docChanges){ if(doc.type==DocumentChangeType.added){ var d=doc.doc.data(); _addCandidate(RTCIceCandidate(d!["candidate"], d["sdpMid"], d["sdpMLineIndex"])); } } });
    } else {
      // CALLEE FIX: Do NOT do get() once - LISTEN for offer, it may come 1-2 sec later
      if(mounted) setState(()=> status="Waiting for offer from ${widget.otherName}...");
      callRef.snapshots().listen((snap) async {
        var data = snap.data(); if(data==null) return;
        if(data["offer"]!=null && !_answered){
          _answered = true;
          try {
            await _pc!.setRemoteDescription(RTCSessionDescription(data["offer"]["sdp"], data["offer"]["type"])); _remoteDescSet = true; await _flush();
            RTCSessionDescription answer = await _pc!.createAnswer(); await _pc!.setLocalDescription(answer); await callRef.update({"answer": answer.toMap(), "status": "accepted"});
            _forceAudio(); if(mounted) setState(()=> status="Accepted - Connecting audio + video...");
          } catch(e){ if(mounted) setState(()=> errorMsg="Answer failed: $e"); }
        }
        if(data["status"]=="ended" && mounted) Navigator.pop(context);
      });
      callRef.collection("callerCandidates").snapshots().listen((snap){ for(var doc in snap.docChanges){ if(doc.type==DocumentChangeType.added){ var d=doc.doc.data(); _addCandidate(RTCIceCandidate(d!["candidate"], d["sdpMid"], d["sdpMLineIndex"])); } } });
    }
    for(int i=0; i<5; i++){ await Future.delayed(Duration(seconds: 2)); if(mounted && speakerOn) await Helper.setSpeakerphoneOn(true); }
  }
  Future<void> _hangUp() async { try { await Helper.setSpeakerphoneOn(false); } catch(e){} try { var doc = await FirebaseFirestore.instance.collection("calls").doc(widget.callId).get(); var data = doc.data(); String newStatus="ended"; if(data!=null && data["status"]=="calling" && widget.isCaller) newStatus="missed"; await FirebaseFirestore.instance.collection("calls").doc(widget.callId).update({"status": newStatus, "endTime": FieldValue.serverTimestamp()}); } catch(e){} await _pc?.close(); await _localStream?.dispose(); if(mounted) Navigator.pop(context); }
  @override void dispose(){ try { _localRenderer.dispose(); } catch(e){} try { _remoteRenderer.dispose(); } catch(e){} try { _pc?.close(); } catch(e){} try { _localStream?.dispose(); } catch(e){} super.dispose(); }
  @override Widget build(BuildContext context) {
    // ERROR SCREEN - never white page
    if(errorMsg.isNotEmpty){
      return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: Text("Call Error"), backgroundColor: Colors.red), body: Padding(padding: EdgeInsets.all(20), child: Column(children: [Icon(Icons.error, color: Colors.red, size: 60), SizedBox(height: 12), Text(errorMsg, style: TextStyle(color: Colors.black, fontSize: 15)), SizedBox(height: 20), ElevatedButton(onPressed: (){ setState(()=> errorMsg=""); _initSafe(); }, child: Text("TRY AGAIN")), SizedBox(height: 10), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), onPressed: (){ Navigator.pop(context); }, child: Text("GO BACK"))])));
    }
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: Text(status), backgroundColor: Colors.black),
      body: Stack(children: [
        if(!audioOnly) Container(color: Colors.black, child: RTCVideoView(_remoteRenderer, mirror: false, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
        if(audioOnly) Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 60, backgroundColor: Colors.deepPurple, child: Text(widget.otherName.isNotEmpty ? widget.otherName.substring(0,1).toUpperCase() : "?", style: TextStyle(fontSize: 50, color: Colors.white))), SizedBox(height: 16), Text("Audio Call - ${widget.otherName}", style: TextStyle(color: Colors.white, fontSize: 20)), SizedBox(height: 8), Text("SPEAK NOW - Can you hear me?", style: TextStyle(color: Colors.yellow, fontSize: 16))])),
        if(!audioOnly && !_remoteVideoGot) Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 16), Text(status, style: TextStyle(color: Colors.white), textAlign: TextAlign.center), SizedBox(height: 8), Text("SPEAK NOW - Voice should work even if video is loading", style: TextStyle(color: Colors.yellow, fontSize: 13))])),
        if(!audioOnly) Positioned(top: 10, right: 10, width: 120, height: 160, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white)), child: RTCVideoView(_localRenderer, mirror: true))),
        Positioned(bottom: 20, left: 0, right: 0, child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [FloatingActionButton(backgroundColor: micOn?Colors.white:Colors.red, mini: true, onPressed: (){ setState(()=> micOn=!micOn); _localStream?.getAudioTracks().forEach((t)=> t.enabled=micOn); }, child: Icon(micOn?Icons.mic:Icons.mic_off, size: 20)), SizedBox(width: 8), FloatingActionButton(backgroundColor: speakerOn?Colors.white:Colors.red, mini: true, onPressed: () async { setState(()=> speakerOn=!speakerOn); await Helper.setSpeakerphoneOn(speakerOn); }, child: Icon(speakerOn?Icons.volume_up:Icons.volume_off, size: 20)), SizedBox(width: 8), FloatingActionButton(backgroundColor: Colors.red, onPressed: _hangUp, child: Icon(Icons.call_end)), SizedBox(width: 8), FloatingActionButton(backgroundColor: camOn?Colors.white:Colors.red, mini: true, onPressed: (){ setState(()=> camOn=!camOn); _localStream?.getVideoTracks().forEach((t)=> t.enabled=camOn); }, child: Icon(camOn?Icons.videocam:Icons.videocam_off, size: 20)), SizedBox(width: 8), if(!audioOnly) FloatingActionButton(backgroundColor: Colors.white, mini: true, onPressed: () async { if(_localStream!=null && _localStream!.getVideoTracks().isNotEmpty) await Helper.switchCamera(_localStream!.getVideoTracks()[0]); }, child: Icon(Icons.switch_camera, size: 20)), ]), SizedBox(height: 8), Text("Mic WHITE = ON  •  Speaker WHITE = LOUD", style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold)), ])),
      ]),
    );
  }
}
