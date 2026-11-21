import 'package:flutter/material.dart';

void main() {
  runApp(const HamzaApp());
}

class HamzaApp extends StatelessWidget {
  const HamzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hamza Jani',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hamza Jani'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Hamza Jani',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Offline Calls - Room Code: 1234'),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {},
                child: const Text('AUDIO CALL'),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () {},
                child: const Text('VIDEO CALL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
