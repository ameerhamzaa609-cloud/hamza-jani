// ===== NEW CHAT - TEXT + PHOTO + VIDEO + VOICE =====
class ChatScreen extends StatefulWidget {
  final String chatId; final String otherUid; final String otherName;
  ChatScreen({required this.chatId, required this.otherUid, required this.otherName});
  @override _ChatScreenState createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  final msgCtrl = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String _recordingPath = "";

  Future<void> sendText() async {
    if(msgCtrl.text.trim().isEmpty) return;
    await _saveMessage({"type": "text", "text": msgCtrl.text.trim()});
    msgCtrl.clear();
  }

  Future<void> _saveMessage(Map<String,dynamic> extra) async {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    String myName = "";
    var myDoc = await FirebaseFirestore.instance.collection("users").doc(myUid).get();
    if(myDoc.exists) myName = (myDoc.data() as Map<String,dynamic>)["username"] ?? "";
    String last = extra["type"]=="text" ? extra["text"] : extra["type"]=="image" ? "📷 Photo" : extra["type"]=="video" ? "🎥 Video" : "🎤 Voice";
    await FirebaseFirestore.instance.collection("chats").doc(widget.chatId).set({
      "members": [myUid, widget.otherUid],
      "lastMessage": last,
      "lastTime": FieldValue.serverTimestamp(),
      "otherName_${myUid}": widget.otherName,
      "otherName_${widget.otherUid}": myName,
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection("chats").doc(widget.chatId).collection("messages").add({
      ...extra, "from": myUid, "fromName": myName, "time": FieldValue.serverTimestamp()
    });
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if(img == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uploading photo...")));
    String path = "chats/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.jpg";
    var ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(File(img.path));
    String url = await ref.getDownloadURL();
    await _saveMessage({"type": "image", "url": url});
  }

  Future<void> pickVideo() async {
    final picker = ImagePicker();
    final XFile? vid = await picker.pickVideo(source: ImageSource.gallery);
    if(vid == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uploading video...")));
    String path = "chats/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.mp4";
    var ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(File(vid.path));
    String url = await ref.getDownloadURL();
    await _saveMessage({"type": "video", "url": url});
  }

  Future<void> startVoice() async {
    await Permission.microphone.request();
    final dir = await getTemporaryDirectory();
    _recordingPath = "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a";
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordingPath);
    setState(()=> _isRecording = true);
  }

  Future<void> stopVoiceAndSend() async {
    await _recorder.stop();
    setState(()=> _isRecording = false);
    if(_recordingPath.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uploading voice...")));
    String path = "chats/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.m4a";
    var ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(File(_recordingPath));
    String url = await ref.getDownloadURL();
    await _saveMessage({"type": "voice", "url": url});
  }

  @override Widget build(BuildContext context){
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("chats").doc(widget.chatId).collection("messages").orderBy("time").snapshots(),
          builder: (c, snap){
            if(!snap.hasData) return Center(child: CircularProgressIndicator());
            return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){
              var d = snap.data!.docs[i].data() as Map<String,dynamic>;
              bool isMe = d["from"] == myUid;
              String type = d["type"] ?? "text";
              Widget content;
              if(type=="image"){
                content = ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(d["url"] ?? "", width: 200, fit: BoxFit.cover, loadingBuilder: (c,child,p){ if(p==null) return child; return Container(width:200,height:150,child:Center(child:CircularProgressIndicator())); }));
              } else if(type=="video"){
                content = VideoMessage(url: d["url"] ?? "");
              } else if(type=="voice"){
                content = VoiceMessage(url: d["url"] ?? "");
              } else {
                content = Text(d["text"] ?? "");
              }
              return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(margin: EdgeInsets.all(6), padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isMe ? Colors.deepPurple[100] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  child: content));
            });
          })),
        Container(
          color: _isRecording ? Colors.red[100] : Colors.white,
          padding: EdgeInsets.all(8),
          child: Row(children: [
            IconButton(icon: Icon(Icons.photo, color: Colors.deepPurple), onPressed: pickImage),
            IconButton(icon: Icon(Icons.videocam, color: Colors.deepPurple), onPressed: pickVideo),
            Expanded(child: TextField(controller: msgCtrl, decoration: InputDecoration(hintText: _isRecording ? "Recording... tap mic to stop" : "Type message...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))),
            GestureDetector(
              onTap: () async { if(_isRecording) await stopVoiceAndSend(); else await startVoice(); },
              child: CircleAvatar(backgroundColor: _isRecording ? Colors.red : Colors.deepPurple, child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white)),
            ),
            SizedBox(width: 6),
            IconButton(icon: Icon(Icons.send, color: Colors.deepPurple, size: 30), onPressed: sendText),
          ]),
        ),
      ]),
    );
  }
}

class VideoMessage extends StatefulWidget { final String url; VideoMessage({required this.url}); @override _VideoMessageState createState() => _VideoMessageState(); }
class _VideoMessageState extends State<VideoMessage> {
  VideoPlayerController? _ctrl;
  @override void initState(){ super.initState(); _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_){ setState((){}); }); }
  @override void dispose(){ _ctrl?.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    if(_ctrl==null || !_ctrl!.value.isInitialized) return Container(width:200,height:120,child:Center(child:CircularProgressIndicator()));
    return GestureDetector(onTap: (){ setState(()=> _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play()); },
      child: Stack(alignment: Alignment.center, children: [SizedBox(width:200, child: AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!))), if(!_ctrl!.value.isPlaying) Icon(Icons.play_circle_fill, size:50, color: Colors.white)]));
  }
}

class VoiceMessage extends StatefulWidget { final String url; VoiceMessage({required this.url}); @override _VoiceMessageState createState() => _VoiceMessageState(); }
class _VoiceMessageState extends State<VoiceMessage> {
  final AudioPlayer _player = AudioPlayer(); bool _playing = false;
  @override void dispose(){ _player.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: Colors.deepPurple), onPressed: () async { if(_playing){ await _player.pause(); setState(()=> _playing=false); } else { await _player.play(UrlSource(widget.url)); setState(()=> _playing=true); _player.onPlayerComplete.listen((_)=> setState(()=> _playing=false)); } }),
      Text("Voice Message", style: TextStyle(color: Colors.black87)),
    ]);
  }
}
