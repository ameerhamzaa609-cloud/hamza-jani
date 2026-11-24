import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) { print("Firebase: $e"); }
  await [Permission.microphone, Permission.camera, Permission.contacts].request();
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
      if (isLogin) { await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass); }
      else {
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
  Future<void> saveToPhonebook(String otherUid, String otherName) async {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection("users").doc(myUid).collection("phonebook").doc(otherUid).set({
      "uid": otherUid, "username": otherName, "savedAt": FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$otherName saved to Phonebook ✅")));
  }
  @override Widget build(BuildContext context) {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text("Hamza Jani - ${_tab==0 ? "Online" : _tab==1 ? "Phonebook" : "History"}"), actions: [IconButton(icon: Icon(Icons.logout), onPressed: ()=> FirebaseAuth.instance.signOut())]),
      body: _tab==0 ? _buildOnlineTab(myUid) : _tab==1 ? PhonebookScreen(myUid: myUid) : CallHistoryScreen(myUid: myUid),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab, onTap: (i)=> setState(()=> _tab=i), type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.wifi), label: "Online"),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: "Phonebook"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
  Widget _buildOnlineTab(String myUid){
    return Padding(padding: EdgeInsets.all(16), child: Column(children: [
      Container(padding: EdgeInsets.all(10), color: Colors.blue[50], child: Row(children: [Icon(Icons.wifi, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text("Online Call - Any distance, needs Internet"))])),
      SizedBox(height: 10),
      TextField(controller: searchController, decoration: InputDecoration(labelText: "Search User ID", suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: search))),
      Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (c,i){
        var data = results[i].data() as Map<String,dynamic>;
        return Card(child: ListTile(
          leading: CircleAvatar(child: Text((data["username"] ?? "?").toString().substring(0,1).toUpperCase())),
          title: Text(data["username"] ?? ""),
          subtitle: Text("Tap CALL or SAVE"),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(Icons.bookmark_add, color: Colors.orange), onPressed: ()=> saveToPhonebook(data["uid"], data["username"] ?? "")),
            ElevatedButton(child: Text("CALL"), onPressed: (){
              String callId = "${myUid}_${data["uid"]}_${DateTime.now().millisecondsSinceEpoch}";
              Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: data["uid"], otherName: data["username"] ?? "")));
            }),
          ]),
        ));
      })),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("calls").where("to", isEqualTo: myUid).where("status", isEqualTo: "calling").snapshots(),
        builder: (c,snap){
          if(!snap.hasData || snap.data!.docs.isEmpty) return SizedBox();
          var callDoc = snap.data!.docs.first; var callData = callDoc.data() as Map<String,dynamic>;
          return Card(color: Colors.green[100], child: ListTile(title: Text("Incoming Online Call"), subtitle: Text("From: ${callData["fromName"] ?? "User"}"),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(child: Text("Accept"), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callDoc.id, isCaller: false, otherUid: callData["from"], otherName: callData["fromName"] ?? ""))); }),
              SizedBox(width: 8),
              ElevatedButton(child: Text("Reject"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await callDoc.reference.update({"status":"missed"}); }),
            ]),
          ));
        },
      ),
    ]));
  }
}

// ===== PHONEBOOK - Shows ALL Phone Contacts + Saved Hamza Users =====
class PhonebookScreen extends StatefulWidget {
  final String myUid; PhonebookScreen({required this.myUid});
  @override _PhonebookScreenState createState() => _PhonebookScreenState();
}
class _PhonebookScreenState extends State<PhonebookScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Contact> phoneContacts = [];
  bool loadingContacts = true;
  String contactError = "";
  @override void initState(){ super.initState(); _tabCtrl = TabController(length: 2, vsync: this); _loadPhoneContacts(); }
  Future<void> _loadPhoneContacts() async {
    try {
      bool perm = await FlutterContacts.requestPermission(readonly: true);
      if(!perm){ setState(()=> {loadingContacts=false, contactError="Contacts permission denied. Allow Contacts in Settings."}); return; }
      List<Contact> all = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
      all.sort((a,b)=> a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      setState(()=> {phoneContacts=all, loadingContacts=false});
    } catch(e){ setState(()=> {loadingContacts=false, contactError=e.toString()}); }
  }
  @override Widget build(BuildContext context){
    return Column(children: [
      TabBar(controller: _tabCtrl, labelColor: Colors.blue, tabs: [Tab(text: "Phone Contacts"), Tab(text: "Hamza Saved")]),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [_phoneContactsList(), _hamzaSavedList()])),
    ]);
  }
  Widget _phoneContactsList(){
    if(loadingContacts) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Loading all contacts from phone...")]));
    if(contactError.isNotEmpty) return Center(child: Padding(padding: EdgeInsets.all(20), child: Text(contactError, textAlign: TextAlign.center)));
    if(phoneContacts.isEmpty) return Center(child: Text("No contacts in phone"));
    return Column(children: [
      Container(padding: EdgeInsets.all(10), color: Colors.green[50], child: Row(children: [Icon(Icons.contacts, color: Colors.green), SizedBox(width: 8), Expanded(child: Text("${phoneContacts.length} contacts from your phone"))])),
      Expanded(child: ListView.builder(itemCount: phoneContacts.length, itemBuilder: (c,i){
        Contact contact = phoneContacts[i];
        String phone = contact.phones.isNotEmpty ? contact.phones.first.number : "";
        String name = contact.displayName.isNotEmpty ? contact.displayName : "Unknown";
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: Colors.green[100], child: Text(name.isNotEmpty ? name.substring(0,1).toUpperCase() : "?")),
          title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(phone.isNotEmpty ? phone : "No number"),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(Icons.search, color: Colors.blue), tooltip: "Find in Hamza", onPressed: () async {
              // Try to find this contact in Hamza users by name
              var q = await FirebaseFirestore.instance.collection("users").where("username", isEqualTo: name.trim().toLowerCase()).get();
              if(q.docs.isEmpty){
                // Try original name
                q = await FirebaseFirestore.instance.collection("users").where("username", isEqualTo: name.trim()).get();
              }
              if(q.docs.isEmpty){
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name is not on Hamza yet. Ask them to create account with User ID: $name")));
              } else {
                var data = q.docs.first.data() as Map<String,dynamic>;
                String otherUid = data["uid"]; String otherName = data["username"] ?? name;
                String callId = "${widget.myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}";
                Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName)));
              }
            }),
            IconButton(icon: Icon(Icons.call, color: Colors.green, size: 28), onPressed: (){
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("To call $name in Hamza, they need a Hamza User ID. Tap 🔍 icon to check.")));
            }),
          ]),
        ));
      })),
    ]);
  }
  Widget _hamzaSavedList(){
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").doc(widget.myUid).collection("phonebook").orderBy("username").snapshots(),
      builder: (c, snap){
        if(!snap.hasData) return Center(child: CircularProgressIndicator());
        if(snap.data!.docs.isEmpty) return Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No saved Hamza users yet.\n\nGo to Online tab > Search a user > Tap Bookmark icon to save here.", textAlign: TextAlign.center)));
        return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){
          var data = snap.data!.docs[i].data() as Map<String,dynamic>;
          String otherName = data["username"] ?? ""; String otherUid = data["uid"] ?? "";
          return Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.blue[100], child: Text(otherName.isNotEmpty ? otherName.substring(0,1).toUpperCase() : "?")),
            title: Text(otherName, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Saved Hamza user - Tap CALL anytime"),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: Icon(Icons.call, color: Colors.green, size: 28), onPressed: (){
                String callId = "${widget.myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}";
                Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName)));
              }),
              IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () async {
                await FirebaseFirestore.instance.collection("users").doc(widget.myUid).collection("phonebook").doc(otherUid).delete();
              }),
            ]),
          ));
        });
      },
    );
  }
}

class CallHistoryScreen extends StatefulWidget { final String myUid; CallHistoryScreen({required this.myUid}); @override _CallHistoryScreenState createState() => _CallHistoryScreenState(); }
class _CallHistoryScreenState extends State<CallHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override void initState(){ super.initState(); _tabCtrl = TabController(length: 4, vsync: this); }
  @override Widget build(BuildContext context){
    return Column(children: [
      TabBar(controller: _tabCtrl, labelColor: Colors.blue, tabs: [Tab(text: "All"), Tab(text: "Dialed"), Tab(text: "Received"), Tab(text: "Missed")]),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [_historyList("all"), _historyList("dialed"), _historyList("received"), _historyList("missed")])),
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
          String otherName = isOutgoing ? (data["toName"] ?? "") : (data["fromName"] ?? "");
          String status = data["status"] ?? "";
          IconData icon; Color color; String label;
          if(isOutgoing){ icon=Icons.call_made; color=Colors.green; label="Dialed"; }
          else if(status=="missed"){ icon=Icons.call_missed; color=Colors.red; label="Missed"; }
          else { icon=Icons.call_received; color=Colors.blue; label="Received"; }
          return ListTile(leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)), title: Text(otherName, style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(label), trailing: IconButton(icon: Icon(Icons.call, color: Colors.green), onPressed: (){
            String otherUid = isOutgoing ? data["to"] : data["from"];
            String callId = "${widget.myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}";
            Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, isCaller: true, otherUid: otherUid, otherName: otherName)));
          }));
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
  RTCPeerConnection? _pc; MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer(); final _remoteRenderer = RTCVideoRenderer();
  String status = "Connecting..."; bool micOn = true; bool camOn = true;
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    await _localRenderer.initialize(); await _remoteRenderer.initialize();
    await [Permission.microphone, Permission.camera].request();
    _localStream = await navigator.mediaDevices.getUserMedia({"audio": true, "video": {"facingMode": "user"}});
    _localRenderer.srcObject = _localStream; setState((){});
    Map<String,dynamic> config = {"iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
      {"urls": "turn:openrelay.metered.ca:80", "username": "openrelayproject", "credential": "openrelayproject"},
      {"urls": "turn:openrelay.metered.ca:443", "username": "openrelayproject", "credential": "openrelayproject"},
    ]};
    _pc = await createPeerConnection(config);
    _localStream!.getTracks().forEach((t){ _pc!.addTrack(t, _localStream!); });
    _pc!.onTrack = (e){ if(e.streams.isNotEmpty){ _remoteRenderer.srcObject = e.streams[0]; setState(()=> status="Connected - ${widget.otherName}"); } };
    _pc!.onAddStream = (s){ _remoteRenderer.srcObject = s; setState(()=> status="Connected - ${widget.otherName}"); };
    _pc!.onIceCandidate = (c){
      if(c.candidate != null){
        FirebaseFirestore.instance.collection("calls").doc(widget.callId).collection(widget.isCaller ? "callerCandidates" : "calleeCandidates").add(c.toMap());
      }
    };
    var callRef = FirebaseFirestore.instance.collection("calls").doc(widget.callId);
    String myUid = FirebaseAuth.instance.currentUser!.uid; String myName = "";
    var myDoc = await FirebaseFirestore.instance.collection("users").doc(myUid).get();
    if(myDoc.exists) myName = (myDoc.data() as Map<String,dynamic>)["username"] ?? "";
    if(widget.isCaller){
      await callRef.set({"from": myUid, "fromName": myName, "to": widget.otherUid, "toName": widget.otherName, "status": "calling", "time": FieldValue.serverTimestamp()});
      RTCSessionDescription offer = await _pc!.createOffer(); await _pc!.setLocalDescription(offer);
      await callRef.update({"offer": offer.toMap()});
      setState(()=> status="Calling ${widget.otherName}...");
      callRef.snapshots().listen((snap){ var d=snap.data(); if(d==null) return; if(d["answer"]!=null && _pc!.getRemoteDescription()==null) _pc!.setRemoteDescription(RTCSessionDescription(d["answer"]["sdp"], d["answer"]["type"])); if(d["status"]=="ended") Navigator.pop(context); });
      callRef.collection("calleeCandidates").snapshots().listen((snap){ for(var doc in snap.docChanges){ if(doc.type==DocumentChangeType.added){ var d=doc.doc.data(); _pc!.addCandidate(RTCIceCandidate(d!["candidate"], d["sdpMid"], d["sdpMLineIndex"])); } } });
    } else {
      var snap = await callRef.get(); var data = snap.data() as Map<String,dynamic>;
      await _pc!.setRemoteDescription(RTCSessionDescription(data["offer"]["sdp"], data["offer"]["type"]));
      RTCSessionDescription answer = await _pc!.createAnswer(); await _pc!.setLocalDescription(answer);
      await callRef.update({"answer": answer.toMap(), "status": "accepted"});
      setState(()=> status="Connected - ${widget.otherName}");
      callRef.collection("callerCandidates").snapshots().listen((snap){ for(var doc in snap.docChanges){ if(doc.type==DocumentChangeType.added){ var d=doc.doc.data(); _pc!.addCandidate(RTCIceCandidate(d!["candidate"], d["sdpMid"], d["sdpMLineIndex"])); } } });
      callRef.snapshots().listen((s){ var d=s.data(); if(d!=null && d["status"]=="ended") Navigator.pop(context); });
    }
  }
  Future<void> _hangUp() async {
    var doc = await FirebaseFirestore.instance.collection("calls").doc(widget.callId).get();
    var data = doc.data(); String newStatus="ended";
    if(data!=null && data["status"]=="calling" && widget.isCaller) newStatus="missed";
    await FirebaseFirestore.instance.collection("calls").doc(widget.callId).update({"status": newStatus, "endTime": FieldValue.serverTimestamp()});
    await _pc?.close(); await _localStream?.dispose(); if(mounted) Navigator.pop(context);
  }
  @override void dispose(){ _localRenderer.dispose(); _remoteRenderer.dispose(); _pc?.close(); _localStream?.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: Text(status), backgroundColor: Colors.black),
      body: Stack(children: [
        Container(child: RTCVideoView(_remoteRenderer, mirror: false, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
        if(_remoteRenderer.srcObject==null) Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 16), Text("Waiting for ${widget.otherName} video...", style: TextStyle(color: Colors.white), textAlign: TextAlign.center)])),
        Positioned(top: 10, right: 10, width: 120, height: 160, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white)), child: RTCVideoView(_localRenderer, mirror: true))),
        Positioned(bottom: 20, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FloatingActionButton(backgroundColor: micOn?Colors.white:Colors.red, onPressed: (){ setState(()=> micOn=!micOn); _localStream?.getAudioTracks().forEach((t)=> t.enabled=micOn); }, child: Icon(micOn?Icons.mic:Icons.mic_off)),
          SizedBox(width: 16), FloatingActionButton(backgroundColor: Colors.red, onPressed: _hangUp, child: Icon(Icons.call_end)), SizedBox(width: 16),
          FloatingActionButton(backgroundColor: camOn?Colors.white:Colors.red, onPressed: (){ setState(()=> camOn=!camOn); _localStream?.getVideoTracks().forEach((t)=> t.enabled=camOn); }, child: Icon(camOn?Icons.videocam:Icons.videocam_off)),
        ])),
      ]),
    );
  }
}
