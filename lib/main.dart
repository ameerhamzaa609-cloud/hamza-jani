import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'firebase_options.dart';

// ===== HAMZA JANI - CLOUDINARY =====
const String cloudName = 'ajritqmx';
const String uploadPreset = 'hamza_jani';

Future<String?> uploadToCloudinary(File file, String type) async {
  try {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$type/upload');
    var req = http.MultipartRequest('POST', url);
    req.fields['upload_preset'] = uploadPreset;
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    var res = await req.send();
    var body = await res.response.stream.bytesToString();
    if (res.statusCode == 200) {
      var j = jsonDecode(body);
      return j['secure_url'] as String?;
    } else {
      debugPrint('Cloudinary error: $body');
      return null;
    }
  } catch (e) {
    debugPrint('Upload error: $e');
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HamzaJaniApp());
}

class HamzaJaniApp extends StatelessWidget {
  const HamzaJaniApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hamza Jani',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

// ===== AUTH GATE =====
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (s.hasData) return const HomeScreen();
        return const LoginScreen();
      },
    );
  }
}

// ===== LOGIN / SIGNUP =====
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignup = true;
  bool _loading = false;
  String _msg = '';

  Future<void> _submit() async {
    final user = _userCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text.trim();
    if (user.isEmpty || pass.length < 6) {
      setState(() => _msg = 'User name likho aur password 6+ hona chahiye');
      return;
    }
    setState(() { _loading = true; _msg = ''; });
    try {
      final email = '$user@hamzajani.app';
      if (_isSignup) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
        await FirebaseFirestore.instance.collection('users').doc(user).set({
          'username': user, 'email': email, 'createdAt': FieldValue.serverTimestamp(), 'online': true,
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
        await FirebaseFirestore.instance.collection('users').doc(user).set({'online': true}, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _msg = e.message ?? 'Error');
    } catch (e) {
      setState(() => _msg = e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade700,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(radius: 55, backgroundColor: Colors.white, child: Icon(Icons.call, size: 60, color: Colors.green)),
                const SizedBox(height: 16),
                const Text('HAMZA JANI', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('Call • Video • Chat', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'User Name (e.g. hamza1)', prefixIcon: Icon(Icons.person))),
                      const SizedBox(height: 12),
                      TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                      const SizedBox(height: 16),
                      if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: Text(_loading ? 'Please wait...' : (_isSignup ? 'CREATE ACCOUNT' : 'LOGIN'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _isSignup = !_isSignup),
                        child: Text(_isSignup ? 'Already have account? Login' : 'New user? Create account'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== HOME =====
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _searchCtrl = TextEditingController();
  String _search = '';

  String get myName {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return email.replaceAll('@hamzajani.app', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hamza Jani'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(myName).set({'online': false}, SetOptions(merge: true));
            await FirebaseAuth.instance.signOut();
          }),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              decoration: InputDecoration(hintText: 'Search user by name... e.g. hamza2', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
            ),
          ),
          Expanded(
            child: _tab == 0 ? _usersList(isChat: false) : _tab == 1 ? _usersList(isChat: true) : _historyList(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: Colors.green,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }

  Widget _usersList({required bool isChat}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').orderBy('username').snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        var docs = s.data!.docs.where((d) {
          final u = (d['username'] ?? '').toString().toLowerCase();
          if (u == myName) return false;
          if (_search.isEmpty) return true;
          return u.contains(_search);
        }).toList();
        if (docs.isEmpty) return const Center(child: Text('No user found.\nAsk friend to create account with same app.'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final u = docs[i]['username'].toString();
            final online = docs[i]['online'] == true;
            return ListTile(
              leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Text(u.isNotEmpty ? u[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold))),
              title: Text(u, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(online ? '● Online' : '○ Offline', style: TextStyle(color: online ? Colors.green : Colors.grey)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.chat, color: Colors.green), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myName: myName, otherName: u)))),
                  IconButton(icon: const Icon(Icons.videocam, color: Colors.blue), onPressed: () => _startCall(u, true)),
                  IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => _startCall(u, false)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _historyList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('calls').where('participants', arrayContains: myName).orderBy('createdAt', descending: true).limit(50).snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (s.data!.docs.isEmpty) return const Center(child: Text('No call history yet'));
        return ListView.builder(
          itemCount: s.data!.docs.length,
          itemBuilder: (c, i) {
            final d = s.data!.docs[i];
            final other = (d['caller'] == myName) ? d['callee'] : d['caller'];
            return ListTile(
              leading: Icon(d['isVideo'] == true ? Icons.videocam : Icons.call, color: Colors.green),
              title: Text(other.toString()),
              subtitle: Text('${d['caller']} → ${d['callee']} • ${d['status'] ?? ''}'),
              trailing: IconButton(icon: const Icon(Icons.call), onPressed: () => _startCall(other.toString(), d['isVideo'] == true)),
            );
          },
        );
      },
    );
  }

  Future<void> _startCall(String other, bool isVideo) async {
    final callId = '${myName}_to_${other}_${DateTime.now().millisecondsSinceEpoch}';
    await FirebaseFirestore.instance.collection('calls').doc(callId).set({
      'caller': myName, 'callee': other, 'participants': [myName, other],
      'isVideo': isVideo, 'status': 'calling', 'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, myName: myName, otherName: other, isCaller: true, isVideo: isVideo)));
  }
}

// ===== CHAT WITH PHOTO / VIDEO / VOICE - CLOUDINARY =====
class ChatScreen extends StatefulWidget {
  final String myName; final String otherName;
  const ChatScreen({super.key, required this.myName, required this.otherName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _uploading = false;

  String get chatId {
    var a = [widget.myName, widget.otherName]..sort();
    return '${a[0]}_${a[1]}';
  }

  Future<void> _sendText() async {
    final t = _msgCtrl.text.trim();
    if (t.isEmpty) return;
    _msgCtrl.clear();
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'from': widget.myName, 'to': widget.otherName, 'type': 'text', 'text': t, 'url': '', 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickAndSend(String kind) async {
    XFile? f;
    if (kind == 'image') f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (kind == 'video') f = await _picker.pickVideo(source: Image
