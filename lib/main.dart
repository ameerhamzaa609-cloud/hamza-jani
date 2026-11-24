import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Fallback if already initialized
    print("Firebase init error: $e");
  }
  runApp(HamzaApp());
}

class HamzaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hamza Jani',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthCheck(),
    );
  }
}

class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasData) {
          return HomeScreen();
        }
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userController = TextEditingController();
  final passController = TextEditingController();
  String error = "";
  bool isLogin = true;

  Future<void> submit() async {
    setState(() => error = "Loading...");
    try {
      String email = "${userController.text.trim()}@hamzajani.com";
      String pass = passController.text.trim();
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
        await FirebaseFirestore.instance.collection("users").doc(FirebaseAuth.instance.currentUser!.uid).set({
          "username": userController.text.trim(),
          "uid": FirebaseAuth.instance.currentUser!.uid,
          "created": FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? e.code);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hamza Jani - ${isLogin ? "Login" : "Create Account"}")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Image.asset("assets/hamza_logo.png", height: 100, errorBuilder: (_,__,___)=> Icon(Icons.phone, size: 80)),
            SizedBox(height: 20),
            TextField(controller: userController, decoration: InputDecoration(labelText: "User ID", border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: passController, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(onPressed: submit, child: Text(isLogin ? "LOGIN" : "CREATE ACCOUNT")),
            TextButton(onPressed: () => setState(() { isLogin = !isLogin; error=""; }), child: Text(isLogin ? "Need account? Create" : "Have account? Login")),
            SizedBox(height: 10),
            Text(error, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();
  List<DocumentSnapshot> results = [];

  Future<void> search() async {
    var q = await FirebaseFirestore.instance.collection("users").where("username", isEqualTo: searchController.text.trim()).get();
    setState(() => results = q.docs);
  }

  Future<void> callUser(String otherUid) async {
    var myUid = FirebaseAuth.instance.currentUser!.uid;
    var callId = "${myUid}_${otherUid}_${DateTime.now().millisecondsSinceEpoch}";
    await FirebaseFirestore.instance.collection("calls").doc(callId).set({
      "from": myUid,
      "to": otherUid,
      "status": "calling",
      "time": FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Calling... $callId")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hamza Jani"),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: searchController, decoration: InputDecoration(labelText: "Search User ID", suffixIcon: IconButton(icon: Icon(Icons.search), onPressed: search))),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (c,i) {
                  var data = results[i].data() as Map<String,dynamic>;
                  return ListTile(
                    title: Text(data["username"] ?? ""),
                    trailing: ElevatedButton(child: Text("CALL"), onPressed: ()=> callUser(data["uid"])),
                  );
                },
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("calls").where("to", isEqualTo: FirebaseAuth.instance.currentUser!.uid).where("status", isEqualTo: "calling").snapshots(),
              builder: (c,snap){
                if (!snap.hasData || snap.data!.docs.isEmpty) return SizedBox();
                var call = snap.data!.docs.first;
                var callData = call.data() as Map<String,dynamic>;
                return Card(
                  color: Colors.green[100],
                  child: ListTile(
                    title: Text("Incoming Call from ${callData["from"]}"),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      ElevatedButton(child: Text("Accept"), onPressed: (){ call.reference.update({"status":"accepted"}); }),
                      SizedBox(width: 8),
                      ElevatedButton(child: Text("Reject"), onPressed: (){ call.reference.update({"status":"rejected"}); }),
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
