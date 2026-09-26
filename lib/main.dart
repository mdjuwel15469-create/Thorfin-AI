import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:android_intent_plus/android_intent.dart';

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

class ThorfinHome extends StatefulWidget {
  const ThorfinHome({super.key});

  @override
  State<ThorfinHome> createState() => _ThorfinHomeState();
}

class _ThorfinHomeState extends State<ThorfinHome> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _speechReady = false;

  String _text = '';
  String _status = 'THORFIN is ready';

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;

        setState(() {
          _isListening = status == 'listening';

          if (_isListening) {
            _status = 'Listening...';
          }
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _isListening = false;
          _status = 'Voice error';
        });
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _speak(String message) async {
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> _openYouTube() async {
    try {
      await _speak('YouTube khol raha hoon');

      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.google.android.youtube',
      );

      await intent.launch();
    } catch (_) {
      await _speak('YouTube open nahi ho paya');
    }
  }

  Future<void> _openChrome() async {
    try {
      await _speak('Chrome khol raha hoon');

      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://www.google.com',
        package: 'com.android.chrome',
      );

      await intent.launch();
    } catch (_) {
      await _speak('Chrome open nahi ho paya');
    }
  }

  Future<void> _openCamera() async {
    try {
      await _speak('Camera khol raha hoon');

      final intent = AndroidIntent(
        action: 'android.media.action.IMAGE_CAPTURE',
      );

      await intent.launch();
    } catch (_) {
      await _speak('Camera open nahi ho paya');
    }
  }

  Future<void> _openMaps() async {
    try {
      await _speak('Maps khol raha hoon');

      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'geo:0,0',
        package: 'com.google.android.apps.maps',
      );

      await intent.launch();
    } catch (_) {
      await _speak('Maps open nahi ho paya');
    }
  }

  Future<void> _openSettings() async {
    try {
      await _speak('Settings khol raha hoon');

      final intent = AndroidIntent(
        action: 'android.settings.SETTINGS',
      );

      await intent.launch();
    } catch (_) {
      await _speak('Settings open nahi ho paya');
    }
  }

  Future<void> _processCommand(String command) async {
    final text = command.toLowerCase().trim();

    if (text.isEmpty) {
      await _speak('Kuch sunai nahi diya bhai');
      return;
    }

    if (text.contains('youtube') ||
        text.contains('you tube')) {
      await _openYouTube();
      return;
    }

    if (text.contains('chrome') ||
        text.contains('google chrome')) {
      await _openChrome();
      return;
    }

    if (text.contains('camera') ||
        text.contains('cam')) {
      await _openCamera();
      return;
    }

    if (text.contains('maps') ||
        text.contains('map') ||
        text.contains('google map')) {
      await _openMaps();
      return;
    }

    if (text.contains('settings') ||
        text.contains('setting')) {
      await _openSettings();
      return;
    }

    if (text == 'stop' ||
        text.contains('band karo') ||
        text.contains('band kar do') ||
        text.contains('ruk jao')) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
          _status = 'Stopped';
        });
      }

      await _speak('Theek hai bhai');
      return;
    }

    if (text.contains('wapas') ||
        text.contains('back') ||
        text.contains('piche') ||
        text.contains('peeche')) {
      await _speak('Theek hai bhai');
      return;
    }

    await _speak('Command samajh nahi aayi bhai');
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      await _initVoice();
    }

    if (!_speechReady) {
      await _speak('Speech recognition ready nahi hai');
      return;
    }

    if (_isListening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
          _status = 'Processing...';
        });
      }

      return;
    }

    setState(() {
      _text = '';
      _status = 'Listening...';
      _isListening = true;
    });

    await _speech.listen(
      onResult: (result) async {
        if (!mounted) return;

        setState(() {
          _text = result.recognizedWords;
        });

        if (result.finalResult) {
          final command = result.recognizedWords;

          setState(() {
            _isListening = false;
            _status = 'Command received';
          });

          await _processCommand(command);
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

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

            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening
                      ? Colors.white
                      : Colors.white24,
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

            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white60,
              ),
            ),

            const SizedBox(height: 25),

            if (_text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  '"$_text"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),

            const Spacer(),

            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.red
                      : Colors.white,
                ),
                child: Icon(
                  _isListening
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                  size: 40,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              _isListening ? 'Tap to stop' : 'Tap to speak',
              style: const TextStyle(
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
