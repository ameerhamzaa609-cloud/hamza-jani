import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';


// ===== HAMZA JANI - CLOUDINARY =====
const String cloudName = 'ajritqmx';
const String uploadPreset = 'hamza_jani';

// ===== RINGTONE PLAYER - HAMZA JANI SPECIAL B =====
final AudioPlayer ringPlayer = AudioPlayer();
Future<void> playHamzaRingtone() async {
  try {
    await ringPlayer.setReleaseMode(ReleaseMode.loop);
    await ringPlayer.play(AssetSource('ringtone.mp3'));
  } catch (e) {
    debugPrint('Ringtone: $e');
  }
}
Future<void> stopRingtone() async {
  try { await ringPlayer.stop(); } catch (_) {}
}

// ===== NOTIFICATIONS =====
final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
Future<void> _firebaseBgHandler(RemoteMessage msg) async {
  await Firebase.initializeApp();
}

Future<String?> uploadToCloudinary(File file, String type) async {
  try {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$type/upload');
  final req = http.MultipartRequest('POST', url);
    req.fields['upload_preset'] = uploadPreset;
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    var streamed = await req.send();
    var body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HamzaJaniApp());
}

class HamzaJaniApp extends StatefulWidget {
  const HamzaJaniApp({super.key});

  @override
  State<HamzaJaniApp> createState() => _HamzaJaniAppState();
}

class _HamzaJaniAppState extends State<HamzaJaniApp> {
  bool _ready = false;
  bool _starting = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startupError = null;
    });

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);

      // Notifications are useful but must never prevent the app from opening.
      try {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        await localNotif.initialize(
          const InitializationSettings(android: androidInit),
        );
        const channel = AndroidNotificationChannel(
          'hamza_calls',
          'Hamza Jani Calls',
          description: 'Incoming calls',
          importance: Importance.max,
          playSound: true,
        );
        await localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      } catch (e) {
        debugPrint('Notification initialization skipped: $e');
      }

      if (!mounted) return;
      setState(() {
        _ready = true;
        _starting = false;
      });
    } catch (e, stack) {
      debugPrint('Hamza Jani startup failed: $e');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _startupError = e.toString();
        _starting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hamza Jani',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: _ready
          ? const AuthGate()
          : _startupError != null
              ? StartupErrorScreen(
                  error: _startupError!,
                  onRetry: _initializeApp,
                )
              : const StartupScreen(),
    );
  }
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B2B22),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HamzaJaniLogo(size: 112),
            SizedBox(height: 18),
            Text(
              'HAMZA JANI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 22),
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Starting app...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const StartupErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Hamza Jani could not start',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please check your internet connection and try again. '
                  'If this message stays, send this error to support:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('TRY AGAIN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class HamzaJaniLogo extends StatelessWidget {
  final double size;
  const HamzaJaniLogo({super.key, this.size = 104});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/hamza_jani_logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
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

// ===== LOGIN =====
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
          'username': user, 'uid': FirebaseAuth.instance.currentUser!.uid, 'email': email, 'createdAt': FieldValue.serverTimestamp(), 'online': true,
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
        await FirebaseFirestore.instance.collection('users').doc(user).set({'username': user, 'uid': FirebaseAuth.instance.currentUser!.uid, 'online': true}, SetOptions(merge: true));
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
      backgroundColor: const Color(0xFF0B2B22),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const HamzaJaniLogo(size: 124),
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

// ===== HOME + INCOMING CALL LISTENER =====
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _searchCtrl = TextEditingController();
  String _search = '';
  StreamSubscription? _incomingSub;
  Set<String> _shownCalls = {};

  String get myName {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return email.replaceAll('@hamzajani.app', '');
  }

  @override
  void initState() {
    super.initState();
    _setupPush();
    _listenIncoming();
  }

  Future<void> _setupPush() async {
    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(myName).set({'fcmToken': token}, SetOptions(merge: true));
      }
      FirebaseMessaging.onMessage.listen((msg) {
        // App open but in background tab - show incoming screen
        if (msg.data['type'] == 'call') {
          _showIncoming(msg.data['callId'] ?? '', msg.data['caller'] ?? 'Unknown', msg.data['isVideo'] == 'true');
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        if (msg.data['type'] == 'call') {
          _showIncoming(msg.data['callId'] ?? '', msg.data['caller'] ?? 'Unknown', msg.data['isVideo'] == 'true');
        }
      });
    } catch (e) { debugPrint('Push setup: $e'); }
  }

  void _listenIncoming() {
    // Filter status locally so this listener does not require a Firestore
    // composite index for (callee, status).
    _incomingSub = FirebaseFirestore.instance
        .collection('calls')
        .where('callee', isEqualTo: myName)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['status'] == 'calling') {
          _showIncoming(
            doc.id,
            (data['caller'] ?? 'Unknown').toString(),
            data['isVideo'] == true,
          );
        }
      }
    }, onError: (Object error) {
      debugPrint('Incoming call listener failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot receive calls: $error')),
        );
      }
    });
  }

  Future<void> _showIncoming(String callId, String caller, bool isVideo) async {
    if (!mounted || callId.isEmpty || _shownCalls.contains(callId)) return;
    _shownCalls.add(callId);

    // Ignore stale push notifications or calls already answered elsewhere.
    try {
      final call = await FirebaseFirestore.instance.collection('calls').doc(callId).get();
      if (!mounted || !call.exists || call.data()?['status'] != 'calling') {
        _shownCalls.remove(callId);
        return;
      }
      final data = call.data()!;
      caller = (data['caller'] ?? caller).toString();
      isVideo = data['isVideo'] == true;
    } catch (e) {
      debugPrint('Checking incoming call failed: $e');
      _shownCalls.remove(callId);
      return;
    }

    // Put the Answer/Reject controls on screen immediately. Audio and
    // notification work must never delay the in-app incoming-call dialog.
    unawaited(playHamzaRingtone().catchError((Object e) {
      debugPrint('Incoming ringtone failed: $e');
    }));

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncomingCallDialog(
        callId: callId,
        caller: caller,
        myName: myName,
        isVideo: isVideo,
        onAnswered: () async { await stopRingtone(); },
        onRejected: () async { await stopRingtone(); },
      ),
    ).then((_) {
      _shownCalls.remove(callId);
    });

    // A notification is secondary while the app is already open. Run it
    // separately so a notification plugin error cannot hide call controls.
    unawaited(() async {
      try {
        await localNotif.show(
          999,
          'Hamza Jani - Incoming Call',
          '$caller is calling you...',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'hamza_calls',
              'Hamza Jani Calls',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Incoming call notification failed: $e');
      }
    }());
  }

  @override
  void dispose() { _incomingSub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hamza Jani'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
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
            child: _tab == 0 ? _usersList() : _tab == 1 ? _usersList() : _historyList(),
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


  Future<void> _openSettings() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(myName);
    final userSnap = await userRef.get();
    if (!mounted) return;
    final nameController = TextEditingController(
      text: (userSnap.data()?['displayName'] ?? userSnap.data()?['username'] ?? myName).toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Display name'),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Your login username and account ID will stay the same.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final displayName = nameController.text.trim();
              if (displayName.isEmpty) return;
              try {
                await userRef.set({'displayName': displayName}, SetOptions(merge: true));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Display name updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update name: $e')),
                  );
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    nameController.dispose();
  }

  Widget _usersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (c, s) {
        if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Cannot load users from Firebase: ${s.error}', textAlign: TextAlign.center)));
        if (s.connectionState == ConnectionState.waiting && !s.hasData) return const Center(child: CircularProgressIndicator());
        var docs = s.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final u = (data['username'] ?? d.id).toString();
          final username = u.toLowerCase();
          final documentId = d.id.toLowerCase();
          final uid = (data['uid'] ?? '').toString().toLowerCase();
          if (username == myName || documentId == myName) return false;
          if (_search.isEmpty) return true;
          return username.contains(_search) ||
              documentId.contains(_search) ||
              uid.contains(_search);
        }).toList()
          ..sort((a, b) {
            final aName = ((a.data() as Map<String, dynamic>)['username'] ?? a.id).toString().toLowerCase();
            final bName = ((b.data() as Map<String, dynamic>)['username'] ?? b.id).toString().toLowerCase();
            return aName.compareTo(bName);
          });
        if (docs.isEmpty) return const Center(child: Text('No user found.'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final userData = docs[i].data() as Map<String, dynamic>;
            final u = (userData['username'] ?? docs[i].id).toString();
            final online = userData['online'] == true;
            return ListTile(
              leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Text(u.isNotEmpty ? u[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold))),
              title: Text((userData['displayName'] ?? u).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
      stream: FirebaseFirestore.instance.collection('calls').where('participants', arrayContains: myName).limit(100).snapshots(),
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 44, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Call history could not be loaded.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${s.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          );
        }
        if (s.connectionState == ConnectionState.waiting && !s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!s.hasData) return const Center(child: Text('No call history yet'));
        if (s.data!.docs.isEmpty) return const Center(child: Text('No call history yet'));
        final historyDocs = List<QueryDocumentSnapshot>.from(s.data!.docs);
        historyDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        return ListView.builder(
          itemCount: historyDocs.length,
          itemBuilder: (c, i) {
            final d = historyDocs[i];
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

// ===== INCOMING CALL DIALOG - WITH RINGTONE =====
class IncomingCallDialog extends StatelessWidget {
  final String callId; final String caller; final String myName; final bool isVideo;
  final VoidCallback onAnswered; final VoidCallback onRejected;
  const IncomingCallDialog({super.key, required this.callId, required this.caller, required this.myName, required this.isVideo, required this.onAnswered, required this.onRejected});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.green.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('HAMZA JANI', style: TextStyle(color: Colors.white70, letterSpacing: 2)),
            const SizedBox(height: 12),
            CircleAvatar(radius: 55, backgroundColor: Colors.white, child: Text(caller.isNotEmpty ? caller[0].toUpperCase() : '?', style: const TextStyle(fontSize: 40, color: Colors.green))),
            const SizedBox(height: 12),
            Text(caller, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            Text(isVideo ? 'Video Call...' : 'Voice Call...', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            const Text('🎵 Hamza Jani Ringtone', style: TextStyle(color: Colors.yellow)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.large(backgroundColor: Colors.red, onPressed: () async {
                  onRejected();
                  await FirebaseFirestore.instance.collection('calls').doc(callId).set({'status': 'ended'}, SetOptions(merge: true));
                  Navigator.pop(context);
                }, child: const Icon(Icons.call_end, color: Colors.white)),
                FloatingActionButton.large(backgroundColor: Colors.white, onPressed: () async {
                  onAnswered();
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, myName: myName, otherName: caller, isCaller: false, isVideo: isVideo)));
                }, child: const Icon(Icons.call, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===== CHAT =====
class ChatScreen extends StatefulWidget {
  final String myName; final String otherName;
  const ChatScreen({super.key, required this.myName, required this.otherName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _picker = img.ImagePicker();
  bool _uploading = false;
  String get chatId {
    final names = [widget.myName.trim().toLowerCase(), widget.otherName.trim().toLowerCase()]..sort();
    return '${names[0]}_${names[1]}';
  }

  Future<void> _sendText() async {
    final t = _msgCtrl.text.trim();
    if (t.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
        'from': widget.myName,
        'to': widget.otherName,
        'type': 'text',
        'text': t,
        'url': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _msgCtrl.clear();
    } catch (e) {
      debugPrint('Message send failed for $chatId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message not sent: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSend(String kind) async {
    img.XFile? f;
    if (kind == 'image') f = await _picker.pickImage(source: img.ImageSource.gallery, imageQuality: 70);
    if (kind == 'video') f = await _picker.pickVideo(source: img.ImageSource.gallery);
    if (kind == 'voice') f = await _picker.pickVideo(source: img.ImageSource.gallery);
    if (f == null) return;
    setState(() => _uploading = true);
    String type = kind == 'video' ? 'video' : (kind == 'voice' ? 'video' : 'image');
    final url = await uploadToCloudinary(File(f.path), type);
    setState(() => _uploading = false);
    if (url == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed - try again')));
      return;
    }
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'from': widget.myName, 'to': widget.otherName, 'type': kind, 'text': '', 'url': url, 'fileName': p.basename(f.path), 'createdAt': FieldValue.serverTimestamp(),
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Column(
        children: [
          if (_uploading) const LinearProgressIndicator(color: Colors.green),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').snapshots(),
              builder: (c, s) {
                if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Cannot load messages from Firebase: ${s.error}', textAlign: TextAlign.center)));
                if (s.connectionState == ConnectionState.waiting && !s.hasData) return const Center(child: CircularProgressIndicator());
                final msgs = List<QueryDocumentSnapshot>.from(s.data!.docs)
                  ..sort((a, b) {
                    final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return -1;
                    if (bTime == null) return 1;
                    return aTime.compareTo(bTime);
                  });
                return ListView.builder(
                  itemCount: msgs.length,
                  itemBuilder: (c, i) {
                    final m = msgs[i];
                    final mine = m['from'] == widget.myName;
                    final type = m['type'] ?? 'text';
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: mine ? Colors.green.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (type == 'text') Text(m['text'] ?? ''),
                            if (type == 'image') ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(m['url'] ?? '', width: 200, errorBuilder: (_, __, ___) => const Text('Image'))),
                            if (type == 'video') Text('🎥 Video: ${m['fileName'] ?? ''}\n${m['url'] ?? ''}', style: const TextStyle(fontSize: 12)),
                            if (type == 'voice') Text('🎤 Voice: ${m['fileName'] ?? ''}\n${m['url'] ?? ''}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(mine ? 'You' : widget.otherName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.photo, color: Colors.green), onPressed: () => _pickAndSend('image')),
                  IconButton(icon: const Icon(Icons.videocam, color: Colors.blue), onPressed: () => _pickAndSend('video')),
                  IconButton(icon: const Icon(Icons.mic, color: Colors.orange), onPressed: () => _pickAndSend('voice')),
                  Expanded(child: TextField(controller: _msgCtrl, decoration: InputDecoration(hintText: 'Message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
                  const SizedBox(width: 6),
                  CircleAvatar(backgroundColor: Colors.green, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendText)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== CALL SCREEN =====
class CallScreen extends StatefulWidget {
  final String callId; final String myName; final String otherName; final bool isCaller; final bool isVideo;
  const CallScreen({super.key, required this.callId, required this.myName, required this.otherName, required this.isCaller, required this.isVideo});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _pc;
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _muted = false; bool _speaker = false; bool _connected = false; bool _front = true;
  String _callStatus = 'Starting call...';
  StreamSubscription? _callSub; StreamSubscription? _candSub;
  Timer? _callTimeout;
  bool _remoteDescriptionReady = false;
  bool _ending = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  @override
  void initState() {
    super.initState();
    _callTimeout = Timer(const Duration(seconds: 45), () async {
      if (!_connected && mounted) {
        try {
          await FirebaseFirestore.instance.collection('calls').doc(widget.callId)
              .set({'status': 'missed', 'endedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        } catch (e) { debugPrint('Call timeout update failed: $e'); }
        _endLocal();
      }
    });
    _init();
  }

  Future<void> _init() async {
    await _local.initialize(); await _remote.initialize();
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': widget.isVideo ? {'facingMode': 'user'} : false});
    _local.srcObject = _localStream;
    final iceServers = await _loadIceServers();
    _pc = await createPeerConnection({'iceServers': iceServers});
    _pc!.onTrack = (e) { if (e.streams.isNotEmpty && mounted) setState(() => _remote.srcObject = e.streams[0]); };
    _pc!.onIceCandidate = (c) async {
      if (c.candidate == null) return;
      try {
        await FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').add({
          'from': widget.myName, 'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex,
        });
      } catch (e) { debugPrint('Saving ICE candidate failed: $e'); }
    };
    _pc!.onConnectionState = (state) {
      if (!mounted) return;
      debugPrint('WebRTC peer connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callTimeout?.cancel();
        setState(() { _connected = true; _callStatus = 'Connected'; });
        unawaited(FirebaseFirestore.instance.collection('calls').doc(widget.callId)
            .set({'status': 'connected', 'connectedAt': FieldValue.serverTimestamp()},
                SetOptions(merge: true))
            .catchError((Object e) => debugPrint('Updating connected call status failed: $e')));
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
        setState(() => _callStatus = 'Connecting audio and video...');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(() => _callStatus = 'Connection failed');
        _endCall();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() => _callStatus = 'Reconnecting...');
      }
    };
    _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));
    if (widget.isCaller) {
      var offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set({'offer': offer.toMap()}, SetOptions(merge: true));
    }
    _callSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((doc) async {
      if (!doc.exists) return;
      var d = doc.data()!;
      if (d['status'] == 'ended') { _endLocal(); return; }
      if (!widget.isCaller && d['offer'] != null && _pc!.getRemoteDescription() == null) {
        await _pc!.setRemoteDescription(RTCSessionDescription(d['offer']['sdp'], d['offer']['type']));
        _remoteDescriptionReady = true;
        await _flushPendingCandidates();
        var ans = await _pc!.createAnswer();
        await _pc!.setLocalDescription(ans);
        await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set({'answer': ans.toMap(), 'status': 'accepted'}, SetOptions(merge: true));
      }
      if (widget.isCaller && d['answer'] != null && _pc!.getRemoteDescription() == null) {
        await _pc!.setRemoteDescription(RTCSessionDescription(d['answer']['sdp'], d['answer']['type']));
        _remoteDescriptionReady = true;
        await _flushPendingCandidates();
      }
    }, onError: (e) { debugPrint('Call signaling listener failed: $e'); if (mounted) _endCall(); });
    _candSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').snapshots().listen((snap) {
      for (var doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          var cd = doc.doc.data()!;
          if (cd['from'] != widget.myName && cd['candidate'] != null) {
            final candidate = RTCIceCandidate(cd['candidate'], cd['sdpMid'], cd['sdpMLineIndex']);
            if (_remoteDescriptionReady) {
              _pc!.addCandidate(candidate).catchError((e) => debugPrint('Adding ICE candidate failed: $e'));
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        }
      }
    }, onError: (e) { debugPrint('ICE candidate listener failed: $e'); });
  }

  // Fetch short-lived TURN credentials from our authenticated Worker.
  // The Cloudflare API secret must never be embedded in this mobile app.
  Future<List<Map<String, dynamic>>> _loadIceServers() async {
    const endpoint = String.fromEnvironment('TURN_CONFIG_URL');
    if (endpoint.isEmpty) {
      _callStatus = 'TURN not configured yet';
      return [{'urls': 'stun:stun.l.google.com:19302'}];
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('You must be signed in to place a call');
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw HttpException('TURN service returned ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final servers = body['iceServers'];
      if (servers is! List || servers.isEmpty) {
        throw const FormatException('TURN service returned no ICE servers');
      }
      _callStatus = 'Connecting securely...';
      return servers.map((server) => Map<String, dynamic>.from(server as Map)).toList();
    } catch (e) {
      debugPrint('TURN credentials unavailable: $e');
      _callStatus = 'TURN unavailable — trying direct connection';
      return [{'urls': 'stun:stun.l.google.com:19302'}];
    }
  }

  Future<void> _flushPendingCandidates() async {
    final pending = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in pending) {
      try { await _pc?.addCandidate(candidate); }
      catch (e) { debugPrint('Queued ICE candidate failed: $e'); }
    }
  }

  Future<void> _toggleMute() async {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _muted);
    setState(() => _muted = !_muted);
  }
  Future<void> _toggleSpeaker() async {
    _localStream?.getAudioTracks().forEach((t) => t.enableSpeakerphone(!_speaker));
    setState(() => _speaker = !_speaker);
  }
  Future<void> _switchCamera() async {
    try {
      final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
      if (tracks.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera is not available in this call')),
        );
        return;
      }
      await Helper.switchCamera(tracks.first);
      if (mounted) setState(() => _front = !_front);
    } catch (e) {
      debugPrint('Camera switch failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not switch camera: $e')),
      );
    }
  }
  Future<void> _endCall() async {
    await stopRingtone();
    await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set({'status': 'ended'}, SetOptions(merge: true));
    _endLocal();
  }
  void _endLocal() async {
    if (_ending) return;
    _ending = true;
    _callTimeout?.cancel();
    await _callSub?.cancel(); await _candSub?.cancel();
    await _pc?.close(); await _localStream?.dispose();
    _local.dispose(); _remote.dispose();
    if (mounted && Navigator.of(context).canPop()) Navigator.pop(context);
  }
  @override
  void dispose() {
    _callTimeout?.cancel();
    _callSub?.cancel(); _candSub?.cancel();
    _pc?.close(); _localStream?.dispose(); _local.dispose(); _remote.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: widget.isVideo
                ? RTCVideoView(_remote, mirror: false)
                : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircleAvatar(radius: 60, child: Text(widget.otherName[0].toUpperCase(), style: const TextStyle(fontSize: 40))),
                    const SizedBox(height: 16),
                    Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 24)),
                    Text(_callStatus, style: const TextStyle(color: Colors.white70)),
                  ]))),
            if (widget.isVideo) Positioned(
              top: 16, right: 16, width: 120, height: 170,
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_local, mirror: _front)),
            ),
            if (widget.isVideo && !_connected) Positioned(
              top: 16, left: 16, right: 150,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text(_callStatus, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            Positioned(bottom: 30, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              FloatingActionButton(backgroundColor: _muted ? Colors.white : Colors.grey.shade800, onPressed: _toggleMute, child: Icon(_muted ? Icons.mic_off : Icons.mic, color: _muted ? Colors.black : Colors.white)),
              FloatingActionButton(backgroundColor: _speaker ? Colors.white : Colors.grey.shade800, onPressed: _toggleSpeaker, child: Icon(Icons.volume_up, color: _speaker ? Colors.black : Colors.white)),
              if (widget.isVideo) FloatingActionButton(backgroundColor: Colors.grey.shade800, onPressed: _switchCamera, child: const Icon(Icons.switch_camera, color: Colors.white)),
              FloatingActionButton(backgroundColor: Colors.red, onPressed: _endCall, child: const Icon(Icons.call_end, color: Colors.white)),
            ])),
          ],
        ),
      ),
    );
  }
}
