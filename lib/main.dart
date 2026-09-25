import 'package:flutter/material.dart';

void main() {
  runApp(const ThorfinApp());
}

class ThorfinApp extends StatelessWidget {
  const ThorfinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'THORFIN AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const ThorfinHome(),
    );
  }
}

class ThorfinHome extends StatelessWidget {
  const ThorfinHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F14),
        title: const Text(
          'THORFIN AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Thorfin Logo
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white24,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Hello Juwel',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'THORFIN is ready.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white60,
              ),
            ),

            const Spacer(),

            // Microphone button
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 38,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Tap to speak',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
