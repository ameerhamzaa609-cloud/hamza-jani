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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
          surface: const Color(0xFF171717),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101010),
          foregroundColor: Color(0xFFD4AF37),
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFD4AF37),
          foregroundColor: Color(0xFF000000),
        ),
        dividerColor: Color(0xFF333333),
      ),
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
      backgroundColor: Color(0xFF000000),
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
      backgroundColor: const Color(0xFF000000),
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

// ===== LOGIN: PHONE OTP AND EXISTING ACCOUNTS =====
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState()=>_LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen>{
 final _phone=TextEditingController(),_otp=TextEditingController(),_user=TextEditingController(),_pass=TextEditingController();
 bool _phoneMode=true,_busy=false; String _message=''; String? _verificationId;
 Future<void> _savePhone(User user) async {
  final number=user.phoneNumber;if(number==null||number.isEmpty)throw StateError('Verified phone number missing.');
  final ref=FirebaseFirestore.instance.collection('users').doc(number);final old=await ref.get();final data=old.data()??{};
  await ref.set({'username':number,'phoneNumber':number,'phoneSearch':number.replaceAll(RegExp(r'[^0-9]'),''),'uid':user.uid,
   'displayName':data['displayName']??'New User','discoverableByPhone':data['discoverableByPhone']!=false,
   if(!old.exists)'createdAt':FieldValue.serverTimestamp(),'online':true},SetOptions(merge:true));
  final discoverable=data['discoverableByPhone']!=false;
  await FirebaseFirestore.instance.collection('publicProfiles').doc(user.uid).set({
   'uid':user.uid,'username':number,'displayName':data['displayName']??'New User',
   'discoverableByPhone':discoverable,'online':true,
   if(discoverable)'phoneNumber':number,'phoneSearch':if(discoverable)number.replaceAll(RegExp(r'[^0-9]'),''),
   if(data['photoUrl']!=null)'photoUrl':data['photoUrl']
  },SetOptions(merge:true));
 }
 Future<void> _sendOtp() async {
  final number=_phone.text.trim().replaceAll(' ','');
  if(!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(number)){setState(()=>_message='Enter phone with country code, e.g. +971501234567');return;}
  setState(()=>_busy=true);
  try{await FirebaseAuth.instance.verifyPhoneNumber(phoneNumber:number,timeout:const Duration(seconds:60),
   verificationCompleted:(c)async{try{final r=await FirebaseAuth.instance.signInWithCredential(c);await _savePhone(r.user!);}catch(e){if(mounted)setState(()=>_message='$e');}},
   verificationFailed:(e){if(mounted)setState(()=>_message=e.message??'OTP failed');},
   codeSent:(id,t){if(mounted)setState((){_verificationId=id;_message='OTP sent by SMS';});},
   codeAutoRetrievalTimeout:(id){_verificationId=id;});
  }catch(e){if(mounted)setState(()=>_message='Could not send OTP: $e');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 Future<void> _verifyOtp() async {
  if(_verificationId==null||_otp.text.trim().length!=6){setState(()=>_message='Enter the 6-digit OTP');return;}
  setState(()=>_busy=true);
  try{final c=PhoneAuthProvider.credential(verificationId:_verificationId!,smsCode:_otp.text.trim());final r=await FirebaseAuth.instance.signInWithCredential(c);await _savePhone(r.user!);}
  on FirebaseAuthException catch(e){if(mounted)setState(()=>_message=e.message??'OTP verification failed');}
  catch(e){if(mounted)setState(()=>_message='$e');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 Future<void> _oldLogin() async {
  final name=_user.text.trim().toLowerCase(),password=_pass.text;
  if(name.isEmpty||password.isEmpty){setState(()=>_message='Enter username and password');return;}
  setState(()=>_busy=true);
  try{await FirebaseAuth.instance.signInWithEmailAndPassword(email:'$name@hamzajani.app',password:password);
   await FirebaseFirestore.instance.collection('users').doc(name).set({'username':name,'uid':FirebaseAuth.instance.currentUser!.uid,'online':true},SetOptions(merge:true));
   await FirebaseFirestore.instance.collection('publicProfiles').doc(FirebaseAuth.instance.currentUser!.uid).set({'uid':FirebaseAuth.instance.currentUser!.uid,'username':name,'displayName':name,'online':true,'discoverableByPhone':false},SetOptions(merge:true));}
  on FirebaseAuthException catch(e){if(mounted)setState(()=>_message=e.message??'Login failed');}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 @override void dispose(){_phone.dispose();_otp.dispose();_user.dispose();_pass.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFF000000),body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
  const HamzaJaniLogo(size:124),const SizedBox(height:16),const Text('HAMZA JANI',style:TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.bold)),const SizedBox(height:24),
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:const Color(0xFF171717),border:Border.all(color:const Color(0xFF5A4A20)),borderRadius:BorderRadius.circular(20)),child:Column(children:[
   Text(_phoneMode?'Register or sign in with phone':'Existing account login',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
   if(_phoneMode)...[
    TextField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone with country code',hintText:'+971501234567')),
    if(_verificationId!=null)TextField(controller:_otp,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'6-digit OTP')),
    ElevatedButton(onPressed:_busy?null:(_verificationId==null?_sendOtp:_verifyOtp),child:Text(_busy?'Please wait':(_verificationId==null?'SEND OTP':'VERIFY OTP'))),
   ]else...[
    TextField(controller:_user,decoration:const InputDecoration(labelText:'Username')),
    TextField(controller:_pass,obscureText:true,decoration:const InputDecoration(labelText:'Password')),
    ElevatedButton(onPressed:_busy?null:_oldLogin,child:const Text('LOGIN')),
   ],
   if(_message.isNotEmpty)Text(_message,style:const TextStyle(color:Colors.red),textAlign:TextAlign.center),
   TextButton(onPressed:()=>setState((){_phoneMode=!_phoneMode;_verificationId=null;_message='';}),child:Text(_phoneMode?'Existing account? Login':'New user? Register with phone OTP')),
  ]))
 ])))));
}

// ===== COMMUNITIES =====
class CommunityScreen extends StatefulWidget {
  final String myName;
  const CommunityScreen({super.key, required this.myName});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  Future<void> _createCommunity() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New community'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Community name',
            hintText: 'e.g. Family',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('CREATE')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('communities').add({
        'name': name,
        'createdByUid': user.uid,
        'createdByName': widget.myName,
        'memberUids': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create community: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in again.'));
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('communities')
            .where('memberUids', arrayContains: uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Could not load communities: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 14),
                Text('Stay connected', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Create a community to bring related groups together.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ]),
            ));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF2A2415), child: Icon(Icons.groups, color: Color(0xFFD4AF37))),
                title: Text((data['name'] ?? 'Community').toString()),
                subtitle: Text('${(data['memberUids'] as List?)?.length ?? 1} member(s)'),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCommunity,
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New community'),
      ),
    );
  }
}

// ===== SETTINGS =====
class SettingsScreen extends StatelessWidget {
  final String myName;
  const SettingsScreen({super.key, required this.myName});

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(myName);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
      body: ListView(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: userRef.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final displayName = (data?['displayName'] ?? data?['username'] ?? myName).toString();
              return ListTile(
                leading: CircleAvatar(radius: 27, child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')),
                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Profile and personal information'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(myName: myName))),
              );
            },
          ),
          const Divider(),
          const ListTile(title: Text('ACCOUNT', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.person_outline), title: const Text('Account'),
            subtitle: const Text('Your phone number and account details'),
            onTap: () => showDialog<void>(context: context, builder: (c) => AlertDialog(
              title: const Text('Account'), content: Text('Signed in as ${FirebaseAuth.instance.currentUser?.phoneNumber ?? myName}'),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
            )),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline), title: const Text('Privacy'),
            subtitle: const Text('Control who can find you by phone number'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacySettingsScreen(myName: myName))),
          ),
          const Divider(),
          const ListTile(title: Text('CHATS', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold))),
          const ListTile(leading: Icon(Icons.chat_outlined), title: Text('Chats'), subtitle: Text('Your conversations and message settings')),
          const Divider(),
          const ListTile(title: Text('NOTIFICATIONS'), leading: Icon(Icons.notifications_outlined), subtitle: Text('Call and message alerts')),
          const Divider(),
          const ListTile(title: Text('STORAGE AND DATA'), leading: Icon(Icons.storage_outlined), subtitle: Text('Media and data usage')),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Log out'),
            onTap: () async {
              await userRef.set({'online': false}, SetOptions(merge: true));
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const ListTile(title: Text('Hamza Jani', style: TextStyle(color: Colors.grey)), subtitle: Text('Messaging and calling')),
        ],
      ),
    );
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  final String myName;
  const PrivacySettingsScreen({super.key, required this.myName});
  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('users').doc(myName);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy'), backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final discoverable = data['discoverableByPhone'] != false;
          return SwitchListTile(
            title: const Text('Find me by phone number'),
            subtitle: const Text('When off, other users cannot find you using your phone number.'),
            value: discoverable,
            onChanged: (value) => ref.set({'discoverableByPhone': value}, SetOptions(merge: true)),
          );
        },
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
  bool _showHistory = false;
  final _searchCtrl = TextEditingController();
  String _search = '';
  StreamSubscription? _incomingSub;
  Set<String> _shownCalls = {};

  String get myName {
    final user=FirebaseAuth.instance.currentUser; final email=user?.email??'';
    if(email.isNotEmpty)return email.replaceAll('@hamzajani.app','');
    return user?.phoneNumber??user?.uid??'user';
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
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('privateUsers').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
        }
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
        .where('participants', arrayContains: myName)
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
        title: Text(const ['Chats', 'Updates', 'Communities', 'Calls'][_tab]),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.settings), tooltip: 'Settings', onPressed: _openSettings),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Log out', onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(myName).set({'online': false}, SetOptions(merge: true));
            await FirebaseFirestore.instance.collection('publicProfiles').doc(FirebaseAuth.instance.currentUser!.uid).set({'online':false},SetOptions(merge:true));
            await FirebaseAuth.instance.signOut();
          }),
        ],
      ),
      body: _tab == 1
          ? StatusScreen(myName: myName)
          : _tab == 2
              ? CommunityScreen(myName: myName)
              : Column(children: [
                  if (_tab == 0 || _tab == 3)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: _tab == 0 ? 'Search chats' : 'Search contacts by name or phone',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  if (_tab == 3)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showHistory = !_showHistory),
                        icon: const Icon(Icons.history),
                        label: Text(_showHistory ? 'Show contacts' : 'Call history'),
                      ),
                    ),
                  Expanded(child: _tab == 0 ? _chatsList() : (_showHistory ? _historyList() : _usersList())),
                ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i; _search = ''; _searchCtrl.clear(); _showHistory = false;
        }),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF2A2415),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.circle_outlined), selectedIcon: Icon(Icons.circle), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Communities'),
          NavigationDestination(icon: Icon(Icons.call_outlined), selectedIcon: Icon(Icons.call), label: 'Calls'),
        ],
      ),
    );
  }


  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SettingsScreen(myName: myName),
    ));
  }

  Widget _usersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('publicProfiles').snapshots(),
      builder: (c, s) {
        if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Cannot load users from Firebase: ${s.error}', textAlign: TextAlign.center)));
        if (s.connectionState == ConnectionState.waiting && !s.hasData) return const Center(child: CircularProgressIndicator());
        var docs = s.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final u = (data['username'] ?? d.id).toString();
          final username = u.toLowerCase();
          final documentId = d.id.toLowerCase();
          final uid=(data['uid']??'').toString().toLowerCase(),display=(data['displayName']??'').toString().toLowerCase();
          final phone=(data['phoneNumber']??'').toString().toLowerCase(),phoneKey=(data['phoneSearch']??phone.replaceAll(RegExp(r'[^0-9]'),'')).toString();
          final digits=_search.replaceAll(RegExp(r'[^0-9]'),'');
          final phoneIdentity=username.startsWith('+')&&RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(username),hidden=phoneIdentity&&data['discoverableByPhone']==false;
          if(username==myName||documentId==myName)return false;if(_search.isEmpty)return true;
          return (!hidden&&(username.contains(_search)||documentId.contains(_search)))||uid.contains(_search)||display.contains(_search)||
            (!hidden&&data['discoverableByPhone']!=false&&(phone.contains(_search)||(digits.isNotEmpty&&phoneKey.contains(digits))));
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
              subtitle: Text([online?'● Online':'○ Offline',if(userData['phoneNumber']!=null&&userData['discoverableByPhone']!=false)userData['phoneNumber'].toString()].join(' • '),style:TextStyle(color:online?Colors.green:Colors.grey)),
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

  Widget _chatsList(){return StreamBuilder<QuerySnapshot>(stream:FirebaseFirestore.instance.collection('chats').where('participants',arrayContains:myName).snapshots(),builder:(context,s){
   if(s.hasError)return Center(child:Text('Could not load chats: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());
   final docs=s.data!.docs.where((doc){final d=doc.data() as Map<String,dynamic>;final ps=(d['participants'] as List?)?.map((e)=>e.toString()).toList()??doc.id.split('_');
    if(!ps.contains(myName))return false;if(_search.isEmpty)return true;final other=ps.firstWhere((p)=>p!=myName,orElse:()=>'');return other.toLowerCase().contains(_search)||(d['lastMessage']??'').toString().toLowerCase().contains(_search);
   }).toList()..sort((a,b){final ad=a.data() as Map<String,dynamic>,bd=b.data() as Map<String,dynamic>;final at=ad['updatedAt'] as Timestamp?,bt=bd['updatedAt'] as Timestamp?;if(at==null&&bt==null)return 0;if(at==null)return 1;if(bt==null)return -1;return bt.compareTo(at);});
   if(docs.isEmpty)return const Center(child:Text('No chats yet. Find a contact in Calls to start chatting.'));
   return ListView.builder(itemCount:docs.length,itemBuilder:(context,i){final doc=docs[i],d=doc.data() as Map<String,dynamic>;final ps=(d['participants'] as List?)?.map((e)=>e.toString()).toList()??doc.id.split('_');final other=ps.firstWhere((p)=>p!=myName,orElse:()=>'Contact');
    return ListTile(leading:CircleAvatar(child:Text(other.isNotEmpty?other[0].toUpperCase():'?')),title:Text(other),subtitle:Text((d['lastMessage']??'Tap to open chat').toString(),maxLines:1,overflow:TextOverflow.ellipsis),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatScreen(myName:myName,otherName:other))));
   });
  });}
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
    // Ring the caller while the other phone is being alerted.
    unawaited(playHamzaRingtone());
    if (!mounted) { await stopRingtone(); return; }
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

  Future<void> _startChatCall(bool isVideo) async {
    final callId = '${widget.myName}_to_${widget.otherName}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).set({
        'caller': widget.myName,
        'callee': widget.otherName,
        'participants': [widget.myName, widget.otherName],
        'isVideo': isVideo,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });
      unawaited(playHamzaRingtone());
      if (!mounted) { await stopRingtone(); return; }
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
        callId: callId,
        myName: widget.myName,
        otherName: widget.otherName,
        isCaller: true,
        isVideo: isVideo,
      )));
    } catch (e) {
      await stopRingtone();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start call: $e')),
      );
    }
  }

  Future<void> _sendText() async {
    final t = _msgCtrl.text.trim();
    if (t.isEmpty) return;
    try {
      final chatRef=FirebaseFirestore.instance.collection('chats').doc(chatId);
      await chatRef.set({'participants':[widget.myName,widget.otherName],'lastMessage':t,'lastSender':widget.myName,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
      await chatRef.collection('messages').add({'from':widget.myName,'to':widget.otherName,'type':'text','text':t,'url':'','createdAt':FieldValue.serverTimestamp()});
      if(mounted)_msgCtrl.clear();
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
    final chatRef=FirebaseFirestore.instance.collection('chats').doc(chatId);
    await chatRef.set({'participants':[widget.myName,widget.otherName],'lastMessage':kind=='image'?'Photo':'Video','lastSender':widget.myName,'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    await chatRef.collection('messages').add({'from':widget.myName,'to':widget.otherName,'type':kind,'text':'','url':url,'fileName':p.basename(f.path),'createdAt':FieldValue.serverTimestamp()});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Voice call', icon: const Icon(Icons.call), onPressed: () => _startChatCall(false)),
          IconButton(tooltip: 'Video call', icon: const Icon(Icons.videocam), onPressed: () => _startChatCall(true)),
        ],
      ),
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
class ProfileScreen extends StatefulWidget{final String myName;const ProfileScreen({super.key,required this.myName});@override State<ProfileScreen> createState()=>_ProfileScreenState();}
class _ProfileScreenState extends State<ProfileScreen>{
 final _name=TextEditingController();final _picker=img.ImagePicker();bool _loading=true,_discoverable=true;String? _photo,_phone;
 DocumentReference<Map<String,dynamic>> get _ref=>FirebaseFirestore.instance.collection('users').doc(widget.myName);
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final d=(await _ref.get()).data()??{};_name.text=(d['displayName']??d['username']??widget.myName).toString();_photo=d['photoUrl']?.toString();_phone=d['phoneNumber']?.toString()??FirebaseAuth.instance.currentUser?.phoneNumber;_discoverable=d['discoverableByPhone']!=false;if(mounted)setState(()=>_loading=false);}
 Future<void> _save()async{final n=_name.text.trim();if(n.isEmpty)return;await _ref.set({'displayName':n,'discoverableByPhone':_discoverable,
  if(_discoverable&&_phone!=null)...{'phoneNumber':_phone,'phoneSearch':_phone!.replaceAll(RegExp(r'[^0-9]'),'')},
  if(!_discoverable)...{'phoneNumber':FieldValue.delete(),'phoneSearch':FieldValue.delete()}},SetOptions(merge:true));
  final user=FirebaseAuth.instance.currentUser!;
  await FirebaseFirestore.instance.collection('publicProfiles').doc(user.uid).set({
   'uid':user.uid,'username':widget.myName,'displayName':n,'photoUrl':_photo,
   'discoverableByPhone':_discoverable,'online':true,
   if(_discoverable&&_phone!=null)'phoneNumber':_phone,
   if(_discoverable&&_phone!=null)'phoneSearch':_phone!.replaceAll(RegExp(r'[^0-9]'),''),
   if(!_discoverable)'phoneNumber':FieldValue.delete(),if(!_discoverable)'phoneSearch':FieldValue.delete()
  },SetOptions(merge:true));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Profile saved')));}
 Future<void> _changePhoto()async{final f=await _picker.pickImage(source:img.ImageSource.gallery,imageQuality:75);if(f==null)return;setState(()=>_loading=true);try{final u=await uploadToCloudinary(File(f.path),'image');if(u==null)throw StateError('Upload failed');await _ref.set({'photoUrl':u},SetOptions(merge:true));
  await FirebaseFirestore.instance.collection('publicProfiles').doc(FirebaseAuth.instance.currentUser!.uid).set({'photoUrl':u},SetOptions(merge:true));_photo=u;}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}if(mounted)setState(()=>_loading=false);}
 @override void dispose(){_name.dispose();super.dispose();}
 @override Widget build(BuildContext context){if(_loading)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(22),children:[
  Center(child:GestureDetector(onTap:_changePhoto,child:CircleAvatar(radius:54,backgroundImage:_photo==null?null:NetworkImage(_photo!),child:_photo==null?const Icon(Icons.person,size:48):null))),
  const SizedBox(height:20),TextField(controller:_name,decoration:const InputDecoration(labelText:'Your name',border:OutlineInputBorder())),
  ListTile(leading:const Icon(Icons.phone),title:const Text('Verified phone'),subtitle:Text(_phone??'Not linked')),
  SwitchListTile(title:const Text('Allow people to find me by phone'),value:_discoverable,onChanged:(v)=>setState(()=>_discoverable=v)),
  ElevatedButton(onPressed:_save,child:const Text('SAVE PROFILE')),
 ]);}
}

// ===== STATUS: TEXT OR PHOTO, EXPIRES AFTER 24 HOURS =====
class StatusScreen extends StatefulWidget{final String myName;const StatusScreen({super.key,required this.myName});@override State<StatusScreen> createState()=>_StatusScreenState();}
class _StatusScreenState extends State<StatusScreen>{
 final _picker=img.ImagePicker();bool _uploading=false;
 Future<void> _save(String type,{String text='',String? url})async{final u=(await FirebaseFirestore.instance.collection('users').doc(widget.myName).get()).data()??{};final now=DateTime.now();await FirebaseFirestore.instance.collection('statuses').add({'owner':widget.myName,'displayName':u['displayName']??widget.myName,'photoUrl':u['photoUrl'],'type':type,'text':text,'mediaUrl':url,'createdAt':Timestamp.fromDate(now),'expiresAt':Timestamp.fromDate(now.add(const Duration(hours:24)))});}
 Future<void> _textStatus()async{final c=TextEditingController();final v=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Share text status'),content:TextField(controller:c,maxLength:500,maxLines:4,decoration:const InputDecoration(hintText:'What is happening?')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('CANCEL')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,c.text.trim()),child:const Text('SHARE'))]));c.dispose();if(v!=null&&v.isNotEmpty){try{await _save('text',text:v);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}}
 Future<void> _photoStatus()async{final f=await _picker.pickImage(source:img.ImageSource.gallery,imageQuality:80);if(f==null)return;setState(()=>_uploading=true);try{final u=await uploadToCloudinary(File(f.path),'image');if(u==null)throw StateError('Upload failed');await _save('image',url:u);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>_uploading=false);}}
 @override Widget build(BuildContext context)=>Column(children:[
  Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_uploading?null:_textStatus,icon:const Icon(Icons.edit),label:const Text('Text status'))),const SizedBox(width:8),Expanded(child:ElevatedButton.icon(onPressed:_uploading?null:_photoStatus,icon:const Icon(Icons.photo),label:Text(_uploading?'Uploading':'Photo status')))])),
  Expanded(child:StreamBuilder<QuerySnapshot>(stream:FirebaseFirestore.instance.collection('statuses').where('expiresAt',isGreaterThan:Timestamp.now()).snapshots(),builder:(context,s){
   if(s.hasError)return Center(child:Text('Status error: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());
   final docs=s.data!.docs.toList()..sort((a,b){final x=(a.data() as Map<String,dynamic>)['createdAt'] as Timestamp?,y=(b.data() as Map<String,dynamic>)['createdAt'] as Timestamp?;if(x==null&&y==null)return 0;if(x==null)return 1;if(y==null)return -1;return y.compareTo(x);});
   if(docs.isEmpty)return const Center(child:Text('No status yet. Share your first update.'));
   return ListView.builder(itemCount:docs.length,itemBuilder:(context,i){final d=docs[i].data() as Map<String,dynamic>;final n=(d['displayName']??d['owner']??'User').toString();final p=d['photoUrl']?.toString();final t=d['createdAt'] as Timestamp?;final age=t==null?'':DateTime.now().difference(t.toDate()).inHours.toString()+'h ago';
    return ListTile(leading:CircleAvatar(backgroundImage:p==null||p.isEmpty?null:NetworkImage(p),child:p==null||p.isEmpty?Text(n.isNotEmpty?n[0].toUpperCase():'?'):null),title:Text(d['owner']==widget.myName?'My status':n),subtitle:Text(d['type']=='image'?'Photo • $age':'${d['text']??''} • $age',maxLines:1,overflow:TextOverflow.ellipsis),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StatusViewer(data:d))));
   });
  })),
 ]);}
class StatusViewer extends StatelessWidget{final Map<String,dynamic> data;const StatusViewer({super.key,required this.data});@override Widget build(BuildContext context){final image=data['type']=='image';return Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,foregroundColor:Colors.white,title:Text((data['displayName']??'Status').toString())),body:Center(child:image?InteractiveViewer(child:Image.network((data['mediaUrl']??'').toString(),fit:BoxFit.contain)):Padding(padding:const EdgeInsets.all(24),child:Text((data['text']??'').toString(),textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:26)))));}}
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
        unawaited(stopRingtone());
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
      if (widget.isCaller && ['accepted','connected','ended','missed','rejected'].contains(d['status'])) unawaited(stopRingtone());
      if (d['status'] == 'ended' || d['status'] == 'missed' || d['status'] == 'rejected') { _endLocal(); return; }
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
    await stopRingtone();
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
                  onTap: () => setState(() => _localVideoExpanded = !_localVideoExpanded),
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
