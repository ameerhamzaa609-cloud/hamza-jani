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

// ===== LOGIN: PHONE OTP + LEGACY ACCOUNT ACCESS =====
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _phoneMode = true;
  bool _loading = false;
  String _msg = '';
  String? _verificationId;

  Future<void> _savePhoneUser(User user) async {
    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) throw StateError('Your verified phone number was not returned by Firebase.');
    final phoneKey = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final userRef = FirebaseFirestore.instance.collection('users').doc(phone);
    final existing = await userRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};
    await userRef.set({
      'username': phone,
      'phoneNumber': phone,
      'phoneSearch': phoneKey,
      'uid': user.uid,
      'displayName': (existingData['displayName'] ?? 'New User').toString(),
      'discoverableByPhone': existingData['discoverableByPhone'] != false,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'online': true,
    }, SetOptions(merge: true));
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim().replaceAll(' ', '');
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      setState(() => _msg = 'Enter the full phone number with country code, for example +971501234567.');
      return;
    }
    setState(() { _loading = true; _msg = ''; _verificationId = null; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            final result = await FirebaseAuth.instance.signInWithCredential(credential);
            await _savePhoneUser(result.user!);
          } catch (e) {
            if (mounted) setState(() => _msg = 'Phone sign-in failed: $e');
          }
        },
        verificationFailed: (e) {
          if (mounted) setState(() { _loading = false; _msg = e.message ?? 'Could not send OTP.'; });
        },
        codeSent: (id, resendToken) {
          if (!mounted) return;
          setState(() { _verificationId = id; _loading = false; _msg = 'OTP sent. Check your SMS messages.'; });
        },
        codeAutoRetrievalTimeout: (id) {
          _verificationId = id;
        },
      );
    } catch (e) {
      if (mounted) setState(() { _loading = false; _msg = 'Could not send OTP: $e'; });
    }
  }

  Future<void> _verifyOtp() async {
    final id = _verificationId;
    final code = _otpCtrl.text.trim();
    if (id == null || code.length != 6) {
      setState(() => _msg = 'Enter the 6-digit code sent to your phone.');
      return;
    }
    setState(() { _loading = true; _msg = ''; });
    try {
      final credential = PhoneAuthProvider.credential(verificationId: id, smsCode: code);
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      await _savePhoneUser(result.user!);
    } on FirebaseAuthException catch (e) {
      setState(() => _msg = e.message ?? 'OTP verification failed.');
    } catch (e) {
      setState(() => _msg = 'OTP verification failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _legacyLogin() async {
    final username = _userCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _msg = 'Enter your existing username and password.');
      return;
    }
    setState(() { _loading = true; _msg = ''; });
    try {
      final email = '$username@hamzajani.app';
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      await FirebaseFirestore.instance.collection('users').doc(username).set({
        'username': username,
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'online': true,
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      setState(() => _msg = e.message ?? 'Login failed.');
    } catch (e) {
      setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose(); _otpCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
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
                      Text(_phoneMode ? 'Register or sign in with phone' : 'Existing account login',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      if (_phoneMode) ...[
                        TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone number with country code', hintText: '+971501234567', prefixIcon: Icon(Icons.phone))),
                        if (_verificationId != null) ...[
                          const SizedBox(height: 12),
                          TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
                            decoration: const InputDecoration(labelText: '6-digit OTP', prefixIcon: Icon(Icons.sms))),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ElevatedButton(
                          onPressed: _loading ? null : (_verificationId == null ? _sendOtp : _verifyOtp),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: Text(_loading ? 'Please wait...' : (_verificationId == null ? 'SEND OTP' : 'VERIFY OTP & CONTINUE'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )),
                      ] else ...[
                        TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Existing username', prefixIcon: Icon(Icons.person))),
                        const SizedBox(height: 12),
                        TextField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: ElevatedButton(
                          onPressed: _loading ? null : _legacyLogin,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: Text(_loading ? 'Please wait...' : 'LOGIN', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )),
                      ],
                      if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
                      TextButton(
                        onPressed: () => setState(() { _phoneMode = !_phoneMode; _msg = ''; _verificationId = null; }),
                        child: Text(_phoneMode ? 'Already have an old username account? Login' : 'New user? Register with phone OTP'),
                      ),
                      const Text('Your phone number is used to verify your account. You can control phone-number discovery in Profile.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
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
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    if (email.isNotEmpty) return email.replaceAll('@hamzajani.app', '');
    return user?.phoneNumber ?? user?.uid ?? 'user';
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
      body: _tab == 2
          ? ProfileScreen(myName: myName)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone number',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                Expanded(child: _tab == 0 ? _usersList() : _chatsList()),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() { _tab = i; _search = ''; _searchCtrl.clear(); }),
        selectedItemColor: Colors.green,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
          final displayName = (data['displayName'] ?? '').toString().toLowerCase();
          final phone = (data['phoneNumber'] ?? '').toString().toLowerCase();
          final phoneSearch = (data['phoneSearch'] ?? phone.replaceAll(RegExp(r'[^0-9]'), '')).toString();
          final searchDigits = _search.replaceAll(RegExp(r'[^0-9]'), '');
          final isPhoneIdentity = username.startsWith('+') && RegExp(r'^\+[1-9][0-9]{7,14}
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
              subtitle: Text(
                [
                  online ? '● Online' : '○ Offline',
                  if (userData['phoneNumber'] != null && userData['discoverableByPhone'] != false)
                    userData['phoneNumber'].toString(),
                ].join(' • '),
                style: TextStyle(color: online ? Colors.green : Colors.grey),
              ),
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

  Widget _chatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Could not load chats: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? doc.id.split('_');
          if (!participants.contains(myName)) return false;
          if (_search.isEmpty) return true;
          final other = participants.firstWhere((p) => p != myName, orElse: () => '');
          return other.toLowerCase().contains(_search) ||
              (data['lastMessage'] ?? '').toString().toLowerCase().contains(_search);
        }).toList()
          ..sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            final at = ad['updatedAt'] as Timestamp?;
            final bt = bd['updatedAt'] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No chats yet. Search for a contact in Calls to start a conversation.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() => _tab = 0),
                icon: const Icon(Icons.person_search),
                label: const Text('Find contacts'),
              ),
            ]),
          ));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? doc.id.split('_');
            final other = participants.firstWhere((p) => p != myName, orElse: () => 'Contact');
            return ListTile(
              leading: CircleAvatar(child: Text(other.isNotEmpty ? other[0].toUpperCase() : '?')),
              title: Text((data['otherDisplayName'] ?? other).toString()),
              subtitle: Text((data['lastMessage'] ?? 'Tap to open chat').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myName: myName, otherName: other))),
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
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      await chatRef.collection('messages').add({
        'from': widget.myName,
        'to': widget.otherName,
        'type': 'text',
        'text': t,
        'url': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await chatRef.set({
        'participants': [widget.myName, widget.otherName],
        'lastMessage': t,
        'lastSender': widget.myName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    await chatRef.collection('messages').add({
      'from': widget.myName, 'to': widget.otherName, 'type': kind, 'text': '', 'url': url, 'fileName': p.basename(f.path), 'createdAt': FieldValue.serverTimestamp(),
    });
    await chatRef.set({
      'participants': [widget.myName, widget.otherName],
      'lastMessage': kind == 'image' ? 'Photo' : (kind == 'voice' ? 'Voice message' : 'Video'),
      'lastSender': widget.myName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

// ===== PROFILE =====
class ProfileScreen extends StatefulWidget {
  final String myName;
  const ProfileScreen({super.key, required this.myName});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = img.ImagePicker();
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  bool _discoverable = true;
  String? _photoUrl;
  String? _phone;
  Map<String, dynamic> _data = {};

  DocumentReference<Map<String, dynamic>> get _userRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.myName);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final snap = await _userRef.get();
      _data = snap.data() ?? {};
      _nameCtrl.text = (_data['displayName'] ?? _data['username'] ?? widget.myName).toString();
      _photoUrl = _data['photoUrl']?.toString();
      _phone = _data['phoneNumber']?.toString() ?? FirebaseAuth.instance.currentUser?.phoneNumber;
      _discoverable = _data['discoverableByPhone'] != false;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load profile: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await _userRef.set({
        'displayName': name,
        'discoverableByPhone': _discoverable,
        if (_discoverable && _phone != null) ...{
          'phoneNumber': _phone,
          'phoneSearch': _phone!.replaceAll(RegExp(r'[^0-9]'), ''),
        },
        if (!_discoverable) ...{
          'phoneNumber': FieldValue.delete(),
          'phoneSearch': FieldValue.delete(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
    }
  }

  Future<void> _changePhoto() async {
    try {
      final file = await _picker.pickImage(source: img.ImageSource.gallery, imageQuality: 75);
      if (file == null) return;
      setState(() => _loading = true);
      final url = await uploadToCloudinary(File(file.path), 'image');
      if (url == null) throw StateError('Photo upload failed.');
      await _userRef.set({'photoUrl': url}, SetOptions(merge: true));
      if (mounted) setState(() { _photoUrl = url; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update photo: $e')));
    }
  }

  Future<void> _addPhone() async {
    final phoneCtrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify phone number'),
        content: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+971501234567', labelText: 'Phone with country code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, phoneCtrl.text.trim()), child: const Text('SEND OTP')),
        ],
      ),
    );
    phoneCtrl.dispose();
    if (phone == null) return;
    if (!RegExp(r'^\+[1-9][0-9]{7,14}
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
  bool _localVideoExpanded = false;
  String _callStatus = 'Starting call...';
  StreamSubscription? _callSub; StreamSubscription? _candSub;
  Timer? _callTimeout;
  bool _remoteDescriptionReady = false;
  bool _handlingOffer = false;
  bool _handlingAnswer = false;
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
    try {
    if (mounted) setState(() => _callStatus = 'Preparing call...');
    await _local.initialize(); await _remote.initialize();
    // Start calls on the private earpiece; the in-call button can switch to loudspeaker.
    await Helper.setSpeakerphoneOn(false);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': widget.isVideo ? {'facingMode': 'user'} : false});
    _local.srcObject = _localStream;
    final iceServers = await _loadIceServers();
    _pc = await createPeerConnection({'iceServers': iceServers});
    _pc!.onTrack = (e) {
      debugPrint('WebRTC remote track received: ${e.track.kind}, streams=${e.streams.length}');
      if (e.streams.isNotEmpty && mounted) {
        setState(() => _remote.srcObject = e.streams[0]);
      }
    };
    _pc!.onIceConnectionState = (state) {
      debugPrint('WebRTC ICE connection state: $state');
      if (!mounted) return;
      final label = state.toString().split('.').last;
      if (label.toLowerCase().contains('failed')) {
        setState(() => _callStatus = 'Network path failed — TURN may be required');
      } else if (label.toLowerCase().contains('checking')) {
        setState(() => _callStatus = 'Checking network path...');
      } else if (label.toLowerCase().contains('connected') || label.toLowerCase().contains('completed')) {
        setState(() => _callStatus = 'Network path established; waiting for media...');
      }
    };
    _pc!.onIceCandidate = (c) async {
      if (c.candidate == null) return;
      try {
        await FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').add({
          'from': widget.myName,
          'fromUid': FirebaseAuth.instance.currentUser?.uid,
          'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex,
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
        setState(() => _callStatus = 'Connection failed — check network / TURN settings');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() => _callStatus = 'Reconnecting...');
      }
    };
    // Wait for every local audio/video track to be attached before creating SDP.
    // Creating the offer too early can negotiate a call with no media tracks.
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    if (widget.isCaller) {
      var offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set({'offer': offer.toMap()}, SetOptions(merge: true));
    }
    _callSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((doc) async {
      if (!doc.exists) return;
      var d = doc.data()!;
      if (d['status'] == 'ended') { _endLocal(); return; }
      if (!widget.isCaller && d['offer'] != null && !_handlingOffer && !_remoteDescriptionReady) {
        _handlingOffer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['offer']['sdp'], d['offer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set(
            {'answer': answer.toMap(), 'status': 'accepted'}, SetOptions(merge: true));
        } finally {
          _handlingOffer = false;
        }
      }
      if (widget.isCaller && d['answer'] != null && !_handlingAnswer && !_remoteDescriptionReady) {
        _handlingAnswer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['answer']['sdp'], d['answer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
        } finally {
          _handlingAnswer = false;
        }
      }
    }, onError: (e) { debugPrint('Call signaling listener failed: $e'); if (mounted) _endCall(); });
    _candSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').snapshots().listen((snap) {
      for (var doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          var cd = doc.doc.data()!;
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final isOtherUser = cd['fromUid'] != null && myUid != null
              ? cd['fromUid'] != myUid
              : cd['from'] != widget.myName;
          if (isOtherUser && cd['candidate'] != null) {
            final candidate = RTCIceCandidate(
              cd['candidate'] as String?,
              cd['sdpMid'] as String?,
              (cd['sdpMLineIndex'] as num?)?.toInt(),
            );
            if (_remoteDescriptionReady) {
              _pc!.addCandidate(candidate).catchError((e) => debugPrint('Adding ICE candidate failed: $e'));
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('ICE candidate listener failed: $e');
      if (mounted) setState(() => _callStatus = 'Could not receive network candidates');
    });
    } catch (e, st) {
      debugPrint('Call setup failed: $e\\n$st');
      if (mounted) setState(() => _callStatus = 'Call setup failed: $e');
    }
  }

  // Fetch short-lived TURN credentials from our authenticated Worker.
  // The Cloudflare API secret must never be embedded in this mobile app.
  Future<List<Map<String, dynamic>>> _loadIceServers() async {
    const endpoint = String.fromEnvironment('TURN_CONFIG_URL');
    if (endpoint.isEmpty) {
      _callStatus = 'Direct connection only — TURN not configured';
      debugPrint('TURN_CONFIG_URL is empty; using STUN only. Calls may fail across restrictive/mobile networks.');
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
    final nextSpeakerState = !_speaker;
    try {
      await Helper.setSpeakerphoneOn(nextSpeakerState);
      if (mounted) setState(() => _speaker = nextSpeakerState);
    } catch (e) {
      debugPrint('Changing call audio output failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change audio output: $e')),
        );
      }
    }
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
            if (widget.isVideo)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (_localVideoExpanded) setState(() => _localVideoExpanded = false);
                  },
                  child: RTCVideoView(
                    _localVideoExpanded ? _local : _remote,
                    mirror: _localVideoExpanded ? _front : false,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(radius: 60, child: Text(widget.otherName[0].toUpperCase(), style: const TextStyle(fontSize: 40))),
                  const SizedBox(height: 16),
                  Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 24)),
                  Text(_callStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                ])),
              ),
            if (widget.isVideo)
              Positioned(
                top: 16, right: 16, width: 120, height: 170,
                child: GestureDetector(
                  onTap: () => setState(() => _localVideoExpanded = !_localVideoExpanded),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RTCVideoView(
                          _localVideoExpanded ? _remote : _local,
                          mirror: _localVideoExpanded ? false : _front,
                        ),
                        Positioned(
                          right: 6, bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.isVideo) Positioned(
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
).hasMatch(phone.replaceAll(' ', ''))) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone number with country code, e.g. +971501234567')));
      return;
    }
    String? verificationId;
    final sent = Completer<void>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone.replaceAll(' ', ''),
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
            await _saveVerifiedPhone(phone.replaceAll(' ', ''));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not link phone: $e')));
          }
        },
        verificationFailed: (e) {
          if (!sent.isCompleted) sent.completeError(e);
        },
        codeSent: (id, token) {
          verificationId = id;
          if (!sent.isCompleted) sent.complete();
        },
        codeAutoRetrievalTimeout: (id) { verificationId = id; },
      );
      await sent.future.timeout(const Duration(seconds: 65));
      if (verificationId == null || !mounted) return;
      final otpCtrl = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enter OTP'),
          content: TextField(controller: otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
            decoration: const InputDecoration(labelText: '6-digit code')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, otpCtrl.text.trim()), child: const Text('VERIFY')),
          ],
        ),
      );
      otpCtrl.dispose();
      if (code == null || code.length != 6) return;
      final credential = PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: code);
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
      await _saveVerifiedPhone(phone.replaceAll(' ', ''));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone verification failed: $e')));
    }
  }

  Future<void> _saveVerifiedPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    await _userRef.set({
      'discoverableByPhone': _discoverable,
      if (_discoverable) ...{
        'phoneNumber': phone,
        'phoneSearch': digits,
      },
      if (!_discoverable) ...{
        'phoneNumber': FieldValue.delete(),
        'phoneSearch': FieldValue.delete(),
      },
      'uid': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
    if (mounted) setState(() => _phone = phone);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number verified and added to your profile')));
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Center(
          child: GestureDetector(
            onTap: _changePhoto,
            child: Stack(children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: Colors.green.shade100,
                backgroundImage: _photoUrl == null ? null : NetworkImage(_photoUrl!),
                child: _photoUrl == null ? Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 38, color: Colors.green)) : null,
              ),
              const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 17, child: Icon(Icons.camera_alt, size: 18))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        const Center(child: Text('Tap photo to change profile picture', style: TextStyle(color: Colors.grey))),
        const SizedBox(height: 24),
        TextField(controller: _nameCtrl, maxLength: 40,
          decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone),
          title: const Text('Verified phone number'),
          subtitle: Text(_phone ?? 'Not added yet'),
          trailing: _phone == null
              ? TextButton(onPressed: _addPhone, child: const Text('ADD'))
              : const Text('VERIFIED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow people to find me by phone number'),
          subtitle: const Text('When off, your phone number will not appear in contact searches.'),
          value: _discoverable,
          onChanged: (v) => setState(() => _discoverable = v),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save), label: const Text('SAVE PROFILE')),
      ],
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
  bool _localVideoExpanded = false;
  String _callStatus = 'Starting call...';
  StreamSubscription? _callSub; StreamSubscription? _candSub;
  Timer? _callTimeout;
  bool _remoteDescriptionReady = false;
  bool _handlingOffer = false;
  bool _handlingAnswer = false;
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
    try {
    if (mounted) setState(() => _callStatus = 'Preparing call...');
    await _local.initialize(); await _remote.initialize();
    // Start calls on the private earpiece; the in-call button can switch to loudspeaker.
    await Helper.setSpeakerphoneOn(false);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': widget.isVideo ? {'facingMode': 'user'} : false});
    _local.srcObject = _localStream;
    final iceServers = await _loadIceServers();
    _pc = await createPeerConnection({'iceServers': iceServers});
    _pc!.onTrack = (e) {
      debugPrint('WebRTC remote track received: ${e.track.kind}, streams=${e.streams.length}');
      if (e.streams.isNotEmpty && mounted) {
        setState(() => _remote.srcObject = e.streams[0]);
      }
    };
    _pc!.onIceConnectionState = (state) {
      debugPrint('WebRTC ICE connection state: $state');
      if (!mounted) return;
      final label = state.toString().split('.').last;
      if (label.toLowerCase().contains('failed')) {
        setState(() => _callStatus = 'Network path failed — TURN may be required');
      } else if (label.toLowerCase().contains('checking')) {
        setState(() => _callStatus = 'Checking network path...');
      } else if (label.toLowerCase().contains('connected') || label.toLowerCase().contains('completed')) {
        setState(() => _callStatus = 'Network path established; waiting for media...');
      }
    };
    _pc!.onIceCandidate = (c) async {
      if (c.candidate == null) return;
      try {
        await FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').add({
          'from': widget.myName,
          'fromUid': FirebaseAuth.instance.currentUser?.uid,
          'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex,
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
        setState(() => _callStatus = 'Connection failed — check network / TURN settings');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() => _callStatus = 'Reconnecting...');
      }
    };
    // Wait for every local audio/video track to be attached before creating SDP.
    // Creating the offer too early can negotiate a call with no media tracks.
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    if (widget.isCaller) {
      var offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set({'offer': offer.toMap()}, SetOptions(merge: true));
    }
    _callSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((doc) async {
      if (!doc.exists) return;
      var d = doc.data()!;
      if (d['status'] == 'ended') { _endLocal(); return; }
      if (!widget.isCaller && d['offer'] != null && !_handlingOffer && !_remoteDescriptionReady) {
        _handlingOffer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['offer']['sdp'], d['offer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set(
            {'answer': answer.toMap(), 'status': 'accepted'}, SetOptions(merge: true));
        } finally {
          _handlingOffer = false;
        }
      }
      if (widget.isCaller && d['answer'] != null && !_handlingAnswer && !_remoteDescriptionReady) {
        _handlingAnswer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['answer']['sdp'], d['answer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
        } finally {
          _handlingAnswer = false;
        }
      }
    }, onError: (e) { debugPrint('Call signaling listener failed: $e'); if (mounted) _endCall(); });
    _candSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').snapshots().listen((snap) {
      for (var doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          var cd = doc.doc.data()!;
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final isOtherUser = cd['fromUid'] != null && myUid != null
              ? cd['fromUid'] != myUid
              : cd['from'] != widget.myName;
          if (isOtherUser && cd['candidate'] != null) {
            final candidate = RTCIceCandidate(
              cd['candidate'] as String?,
              cd['sdpMid'] as String?,
              (cd['sdpMLineIndex'] as num?)?.toInt(),
            );
            if (_remoteDescriptionReady) {
              _pc!.addCandidate(candidate).catchError((e) => debugPrint('Adding ICE candidate failed: $e'));
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('ICE candidate listener failed: $e');
      if (mounted) setState(() => _callStatus = 'Could not receive network candidates');
    });
    } catch (e, st) {
      debugPrint('Call setup failed: $e\\n$st');
      if (mounted) setState(() => _callStatus = 'Call setup failed: $e');
    }
  }

  // Fetch short-lived TURN credentials from our authenticated Worker.
  // The Cloudflare API secret must never be embedded in this mobile app.
  Future<List<Map<String, dynamic>>> _loadIceServers() async {
    const endpoint = String.fromEnvironment('TURN_CONFIG_URL');
    if (endpoint.isEmpty) {
      _callStatus = 'Direct connection only — TURN not configured';
      debugPrint('TURN_CONFIG_URL is empty; using STUN only. Calls may fail across restrictive/mobile networks.');
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
    final nextSpeakerState = !_speaker;
    try {
      await Helper.setSpeakerphoneOn(nextSpeakerState);
      if (mounted) setState(() => _speaker = nextSpeakerState);
    } catch (e) {
      debugPrint('Changing call audio output failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change audio output: $e')),
        );
      }
    }
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
            if (widget.isVideo)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (_localVideoExpanded) setState(() => _localVideoExpanded = false);
                  },
                  child: RTCVideoView(
                    _localVideoExpanded ? _local : _remote,
                    mirror: _localVideoExpanded ? _front : false,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(radius: 60, child: Text(widget.otherName[0].toUpperCase(), style: const TextStyle(fontSize: 40))),
                  const SizedBox(height: 16),
                  Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 24)),
                  Text(_callStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                ])),
              ),
            if (widget.isVideo)
              Positioned(
                top: 16, right: 16, width: 120, height: 170,
                child: GestureDetector(
                  onTap: () => setState(() => _localVideoExpanded = !_localVideoExpanded),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RTCVideoView(
                          _localVideoExpanded ? _remote : _local,
                          mirror: _localVideoExpanded ? false : _front,
                        ),
                        Positioned(
                          right: 6, bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.isVideo) Positioned(
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
).hasMatch(username);
          final phoneHidden = isPhoneIdentity && data['discoverableByPhone'] == false;
          if (username == myName || documentId == myName) return false;
          if (_search.isEmpty) return true;
          final nameMatch = (!phoneHidden && (username.contains(_search) || documentId.contains(_search))) ||
              uid.contains(_search) || displayName.contains(_search);
          final phoneMatch = !phoneHidden && data['discoverableByPhone'] != false &&
              (phone.contains(_search) || (searchDigits.isNotEmpty && phoneSearch.contains(searchDigits)));
          return nameMatch || phoneMatch;
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
              subtitle: Text(
                [
                  online ? '● Online' : '○ Offline',
                  if (userData['phoneNumber'] != null && userData['discoverableByPhone'] != false)
                    userData['phoneNumber'].toString(),
                ].join(' • '),
                style: TextStyle(color: online ? Colors.green : Colors.grey),
              ),
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

  Widget _chatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Could not load chats: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? doc.id.split('_');
          if (!participants.contains(myName)) return false;
          if (_search.isEmpty) return true;
          final other = participants.firstWhere((p) => p != myName, orElse: () => '');
          return other.toLowerCase().contains(_search) ||
              (data['lastMessage'] ?? '').toString().toLowerCase().contains(_search);
        }).toList()
          ..sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            final at = ad['updatedAt'] as Timestamp?;
            final bt = bd['updatedAt'] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No chats yet. Search for a contact in Calls to start a conversation.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() => _tab = 0),
                icon: const Icon(Icons.person_search),
                label: const Text('Find contacts'),
              ),
            ]),
          ));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? doc.id.split('_');
            final other = participants.firstWhere((p) => p != myName, orElse: () => 'Contact');
            return ListTile(
              leading: CircleAvatar(child: Text(other.isNotEmpty ? other[0].toUpperCase() : '?')),
              title: Text((data['otherDisplayName'] ?? other).toString()),
              subtitle: Text((data['lastMessage'] ?? 'Tap to open chat').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myName: myName, otherName: other))),
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
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      await chatRef.collection('messages').add({
        'from': widget.myName,
        'to': widget.otherName,
        'type': 'text',
        'text': t,
        'url': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await chatRef.set({
        'participants': [widget.myName, widget.otherName],
        'lastMessage': t,
        'lastSender': widget.myName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    await chatRef.collection('messages').add({
      'from': widget.myName, 'to': widget.otherName, 'type': kind, 'text': '', 'url': url, 'fileName': p.basename(f.path), 'createdAt': FieldValue.serverTimestamp(),
    });
    await chatRef.set({
      'participants': [widget.myName, widget.otherName],
      'lastMessage': kind == 'image' ? 'Photo' : (kind == 'voice' ? 'Voice message' : 'Video'),
      'lastSender': widget.myName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

// ===== PROFILE =====
class ProfileScreen extends StatefulWidget {
  final String myName;
  const ProfileScreen({super.key, required this.myName});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = img.ImagePicker();
  final _nameCtrl = TextEditingController();
  bool _loading = true;
  bool _discoverable = true;
  String? _photoUrl;
  String? _phone;
  Map<String, dynamic> _data = {};

  DocumentReference<Map<String, dynamic>> get _userRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.myName);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final snap = await _userRef.get();
      _data = snap.data() ?? {};
      _nameCtrl.text = (_data['displayName'] ?? _data['username'] ?? widget.myName).toString();
      _photoUrl = _data['photoUrl']?.toString();
      _phone = _data['phoneNumber']?.toString() ?? FirebaseAuth.instance.currentUser?.phoneNumber;
      _discoverable = _data['discoverableByPhone'] != false;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load profile: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await _userRef.set({
        'displayName': name,
        'discoverableByPhone': _discoverable,
        if (_discoverable && _phone != null) ...{
          'phoneNumber': _phone,
          'phoneSearch': _phone!.replaceAll(RegExp(r'[^0-9]'), ''),
        },
        if (!_discoverable) ...{
          'phoneNumber': FieldValue.delete(),
          'phoneSearch': FieldValue.delete(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
    }
  }

  Future<void> _changePhoto() async {
    try {
      final file = await _picker.pickImage(source: img.ImageSource.gallery, imageQuality: 75);
      if (file == null) return;
      setState(() => _loading = true);
      final url = await uploadToCloudinary(File(file.path), 'image');
      if (url == null) throw StateError('Photo upload failed.');
      await _userRef.set({'photoUrl': url}, SetOptions(merge: true));
      if (mounted) setState(() { _photoUrl = url; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update photo: $e')));
    }
  }

  Future<void> _addPhone() async {
    final phoneCtrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify phone number'),
        content: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+971501234567', labelText: 'Phone with country code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, phoneCtrl.text.trim()), child: const Text('SEND OTP')),
        ],
      ),
    );
    phoneCtrl.dispose();
    if (phone == null) return;
    if (!RegExp(r'^\+[1-9][0-9]{7,14}
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
  bool _localVideoExpanded = false;
  String _callStatus = 'Starting call...';
  StreamSubscription? _callSub; StreamSubscription? _candSub;
  Timer? _callTimeout;
  bool _remoteDescriptionReady = false;
  bool _handlingOffer = false;
  bool _handlingAnswer = false;
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
    try {
    if (mounted) setState(() => _callStatus = 'Preparing call...');
    await _local.initialize(); await _remote.initialize();
    // Start calls on the private earpiece; the in-call button can switch to loudspeaker.
    await Helper.setSpeakerphoneOn(false);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': widget.isVideo ? {'facingMode': 'user'} : false});
    _local.srcObject = _localStream;
    final iceServers = await _loadIceServers();
    _pc = await createPeerConnection({'iceServers': iceServers});
    _pc!.onTrack = (e) {
      debugPrint('WebRTC remote track received: ${e.track.kind}, streams=${e.streams.length}');
      if (e.streams.isNotEmpty && mounted) {
        setState(() => _remote.srcObject = e.streams[0]);
      }
    };
    _pc!.onIceConnectionState = (state) {
      debugPrint('WebRTC ICE connection state: $state');
      if (!mounted) return;
      final label = state.toString().split('.').last;
      if (label.toLowerCase().contains('failed')) {
        setState(() => _callStatus = 'Network path failed — TURN may be required');
      } else if (label.toLowerCase().contains('checking')) {
        setState(() => _callStatus = 'Checking network path...');
      } else if (label.toLowerCase().contains('connected') || label.toLowerCase().contains('completed')) {
        setState(() => _callStatus = 'Network path established; waiting for media...');
      }
    };
    _pc!.onIceCandidate = (c) async {
      if (c.candidate == null) return;
      try {
        await FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').add({
          'from': widget.myName,
          'fromUid': FirebaseAuth.instance.currentUser?.uid,
          'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex,
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
        setState(() => _callStatus = 'Connection failed — check network / TURN settings');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() => _callStatus = 'Reconnecting...');
      }
    };
    // Wait for every local audio/video track to be attached before creating SDP.
    // Creating the offer too early can negotiate a call with no media tracks.
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    if (widget.isCaller) {
      var offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set({'offer': offer.toMap()}, SetOptions(merge: true));
    }
    _callSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((doc) async {
      if (!doc.exists) return;
      var d = doc.data()!;
      if (d['status'] == 'ended') { _endLocal(); return; }
      if (!widget.isCaller && d['offer'] != null && !_handlingOffer && !_remoteDescriptionReady) {
        _handlingOffer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['offer']['sdp'], d['offer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set(
            {'answer': answer.toMap(), 'status': 'accepted'}, SetOptions(merge: true));
        } finally {
          _handlingOffer = false;
        }
      }
      if (widget.isCaller && d['answer'] != null && !_handlingAnswer && !_remoteDescriptionReady) {
        _handlingAnswer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['answer']['sdp'], d['answer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
        } finally {
          _handlingAnswer = false;
        }
      }
    }, onError: (e) { debugPrint('Call signaling listener failed: $e'); if (mounted) _endCall(); });
    _candSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').snapshots().listen((snap) {
      for (var doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          var cd = doc.doc.data()!;
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final isOtherUser = cd['fromUid'] != null && myUid != null
              ? cd['fromUid'] != myUid
              : cd['from'] != widget.myName;
          if (isOtherUser && cd['candidate'] != null) {
            final candidate = RTCIceCandidate(
              cd['candidate'] as String?,
              cd['sdpMid'] as String?,
              (cd['sdpMLineIndex'] as num?)?.toInt(),
            );
            if (_remoteDescriptionReady) {
              _pc!.addCandidate(candidate).catchError((e) => debugPrint('Adding ICE candidate failed: $e'));
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('ICE candidate listener failed: $e');
      if (mounted) setState(() => _callStatus = 'Could not receive network candidates');
    });
    } catch (e, st) {
      debugPrint('Call setup failed: $e\\n$st');
      if (mounted) setState(() => _callStatus = 'Call setup failed: $e');
    }
  }

  // Fetch short-lived TURN credentials from our authenticated Worker.
  // The Cloudflare API secret must never be embedded in this mobile app.
  Future<List<Map<String, dynamic>>> _loadIceServers() async {
    const endpoint = String.fromEnvironment('TURN_CONFIG_URL');
    if (endpoint.isEmpty) {
      _callStatus = 'Direct connection only — TURN not configured';
      debugPrint('TURN_CONFIG_URL is empty; using STUN only. Calls may fail across restrictive/mobile networks.');
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
    final nextSpeakerState = !_speaker;
    try {
      await Helper.setSpeakerphoneOn(nextSpeakerState);
      if (mounted) setState(() => _speaker = nextSpeakerState);
    } catch (e) {
      debugPrint('Changing call audio output failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change audio output: $e')),
        );
      }
    }
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
            if (widget.isVideo)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (_localVideoExpanded) setState(() => _localVideoExpanded = false);
                  },
                  child: RTCVideoView(
                    _localVideoExpanded ? _local : _remote,
                    mirror: _localVideoExpanded ? _front : false,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(radius: 60, child: Text(widget.otherName[0].toUpperCase(), style: const TextStyle(fontSize: 40))),
                  const SizedBox(height: 16),
                  Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 24)),
                  Text(_callStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                ])),
              ),
            if (widget.isVideo)
              Positioned(
                top: 16, right: 16, width: 120, height: 170,
                child: GestureDetector(
                  onTap: () => setState(() => _localVideoExpanded = !_localVideoExpanded),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RTCVideoView(
                          _localVideoExpanded ? _remote : _local,
                          mirror: _localVideoExpanded ? false : _front,
                        ),
                        Positioned(
                          right: 6, bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.isVideo) Positioned(
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
).hasMatch(phone.replaceAll(' ', ''))) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone number with country code, e.g. +971501234567')));
      return;
    }
    String? verificationId;
    final sent = Completer<void>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone.replaceAll(' ', ''),
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
            await _saveVerifiedPhone(phone.replaceAll(' ', ''));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not link phone: $e')));
          }
        },
        verificationFailed: (e) {
          if (!sent.isCompleted) sent.completeError(e);
        },
        codeSent: (id, token) {
          verificationId = id;
          if (!sent.isCompleted) sent.complete();
        },
        codeAutoRetrievalTimeout: (id) { verificationId = id; },
      );
      await sent.future.timeout(const Duration(seconds: 65));
      if (verificationId == null || !mounted) return;
      final otpCtrl = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enter OTP'),
          content: TextField(controller: otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
            decoration: const InputDecoration(labelText: '6-digit code')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, otpCtrl.text.trim()), child: const Text('VERIFY')),
          ],
        ),
      );
      otpCtrl.dispose();
      if (code == null || code.length != 6) return;
      final credential = PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: code);
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
      await _saveVerifiedPhone(phone.replaceAll(' ', ''));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone verification failed: $e')));
    }
  }

  Future<void> _saveVerifiedPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    await _userRef.set({
      'discoverableByPhone': _discoverable,
      if (_discoverable) ...{
        'phoneNumber': phone,
        'phoneSearch': digits,
      },
      if (!_discoverable) ...{
        'phoneNumber': FieldValue.delete(),
        'phoneSearch': FieldValue.delete(),
      },
      'uid': FirebaseAuth.instance.currentUser?.uid,
    }, SetOptions(merge: true));
    if (mounted) setState(() => _phone = phone);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number verified and added to your profile')));
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Center(
          child: GestureDetector(
            onTap: _changePhoto,
            child: Stack(children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: Colors.green.shade100,
                backgroundImage: _photoUrl == null ? null : NetworkImage(_photoUrl!),
                child: _photoUrl == null ? Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 38, color: Colors.green)) : null,
              ),
              const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 17, child: Icon(Icons.camera_alt, size: 18))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        const Center(child: Text('Tap photo to change profile picture', style: TextStyle(color: Colors.grey))),
        const SizedBox(height: 24),
        TextField(controller: _nameCtrl, maxLength: 40,
          decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone),
          title: const Text('Verified phone number'),
          subtitle: Text(_phone ?? 'Not added yet'),
          trailing: _phone == null
              ? TextButton(onPressed: _addPhone, child: const Text('ADD'))
              : const Text('VERIFIED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow people to find me by phone number'),
          subtitle: const Text('When off, your phone number will not appear in contact searches.'),
          value: _discoverable,
          onChanged: (v) => setState(() => _discoverable = v),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save), label: const Text('SAVE PROFILE')),
      ],
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
  bool _localVideoExpanded = false;
  String _callStatus = 'Starting call...';
  StreamSubscription? _callSub; StreamSubscription? _candSub;
  Timer? _callTimeout;
  bool _remoteDescriptionReady = false;
  bool _handlingOffer = false;
  bool _handlingAnswer = false;
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
    try {
    if (mounted) setState(() => _callStatus = 'Preparing call...');
    await _local.initialize(); await _remote.initialize();
    // Start calls on the private earpiece; the in-call button can switch to loudspeaker.
    await Helper.setSpeakerphoneOn(false);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': widget.isVideo ? {'facingMode': 'user'} : false});
    _local.srcObject = _localStream;
    final iceServers = await _loadIceServers();
    _pc = await createPeerConnection({'iceServers': iceServers});
    _pc!.onTrack = (e) {
      debugPrint('WebRTC remote track received: ${e.track.kind}, streams=${e.streams.length}');
      if (e.streams.isNotEmpty && mounted) {
        setState(() => _remote.srcObject = e.streams[0]);
      }
    };
    _pc!.onIceConnectionState = (state) {
      debugPrint('WebRTC ICE connection state: $state');
      if (!mounted) return;
      final label = state.toString().split('.').last;
      if (label.toLowerCase().contains('failed')) {
        setState(() => _callStatus = 'Network path failed — TURN may be required');
      } else if (label.toLowerCase().contains('checking')) {
        setState(() => _callStatus = 'Checking network path...');
      } else if (label.toLowerCase().contains('connected') || label.toLowerCase().contains('completed')) {
        setState(() => _callStatus = 'Network path established; waiting for media...');
      }
    };
    _pc!.onIceCandidate = (c) async {
      if (c.candidate == null) return;
      try {
        await FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').add({
          'from': widget.myName,
          'fromUid': FirebaseAuth.instance.currentUser?.uid,
          'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex,
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
        setState(() => _callStatus = 'Connection failed — check network / TURN settings');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        setState(() => _callStatus = 'Reconnecting...');
      }
    };
    // Wait for every local audio/video track to be attached before creating SDP.
    // Creating the offer too early can negotiate a call with no media tracks.
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    if (widget.isCaller) {
      var offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set({'offer': offer.toMap()}, SetOptions(merge: true));
    }
    _callSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).snapshots().listen((doc) async {
      if (!doc.exists) return;
      var d = doc.data()!;
      if (d['status'] == 'ended') { _endLocal(); return; }
      if (!widget.isCaller && d['offer'] != null && !_handlingOffer && !_remoteDescriptionReady) {
        _handlingOffer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['offer']['sdp'], d['offer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          await FirebaseFirestore.instance.collection('calls').doc(widget.callId).set(
            {'answer': answer.toMap(), 'status': 'accepted'}, SetOptions(merge: true));
        } finally {
          _handlingOffer = false;
        }
      }
      if (widget.isCaller && d['answer'] != null && !_handlingAnswer && !_remoteDescriptionReady) {
        _handlingAnswer = true;
        try {
          await _pc!.setRemoteDescription(RTCSessionDescription(d['answer']['sdp'], d['answer']['type']));
          _remoteDescriptionReady = true;
          await _flushPendingCandidates();
        } finally {
          _handlingAnswer = false;
        }
      }
    }, onError: (e) { debugPrint('Call signaling listener failed: $e'); if (mounted) _endCall(); });
    _candSub = FirebaseFirestore.instance.collection('calls').doc(widget.callId).collection('candidates').snapshots().listen((snap) {
      for (var doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          var cd = doc.doc.data()!;
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          final isOtherUser = cd['fromUid'] != null && myUid != null
              ? cd['fromUid'] != myUid
              : cd['from'] != widget.myName;
          if (isOtherUser && cd['candidate'] != null) {
            final candidate = RTCIceCandidate(
              cd['candidate'] as String?,
              cd['sdpMid'] as String?,
              (cd['sdpMLineIndex'] as num?)?.toInt(),
            );
            if (_remoteDescriptionReady) {
              _pc!.addCandidate(candidate).catchError((e) => debugPrint('Adding ICE candidate failed: $e'));
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('ICE candidate listener failed: $e');
      if (mounted) setState(() => _callStatus = 'Could not receive network candidates');
    });
    } catch (e, st) {
      debugPrint('Call setup failed: $e\\n$st');
      if (mounted) setState(() => _callStatus = 'Call setup failed: $e');
    }
  }

  // Fetch short-lived TURN credentials from our authenticated Worker.
  // The Cloudflare API secret must never be embedded in this mobile app.
  Future<List<Map<String, dynamic>>> _loadIceServers() async {
    const endpoint = String.fromEnvironment('TURN_CONFIG_URL');
    if (endpoint.isEmpty) {
      _callStatus = 'Direct connection only — TURN not configured';
      debugPrint('TURN_CONFIG_URL is empty; using STUN only. Calls may fail across restrictive/mobile networks.');
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
    final nextSpeakerState = !_speaker;
    try {
      await Helper.setSpeakerphoneOn(nextSpeakerState);
      if (mounted) setState(() => _speaker = nextSpeakerState);
    } catch (e) {
      debugPrint('Changing call audio output failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change audio output: $e')),
        );
      }
    }
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
            if (widget.isVideo)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (_localVideoExpanded) setState(() => _localVideoExpanded = false);
                  },
                  child: RTCVideoView(
                    _localVideoExpanded ? _local : _remote,
                    mirror: _localVideoExpanded ? _front : false,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(radius: 60, child: Text(widget.otherName[0].toUpperCase(), style: const TextStyle(fontSize: 40))),
                  const SizedBox(height: 16),
                  Text(widget.otherName, style: const TextStyle(color: Colors.white, fontSize: 24)),
                  Text(_callStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                ])),
              ),
            if (widget.isVideo)
              Positioned(
                top: 16, right: 16, width: 120, height: 170,
                child: GestureDetector(
                  onTap: () => setState(() => _localVideoExpanded = !_localVideoExpanded),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RTCVideoView(
                          _localVideoExpanded ? _remote : _local,
                          mirror: _localVideoExpanded ? false : _front,
                        ),
                        Positioned(
                          right: 6, bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.isVideo) Positioned(
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
