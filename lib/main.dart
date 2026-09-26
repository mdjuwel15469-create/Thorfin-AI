import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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

  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  GenerativeModel? _model;
  ChatSession? _chat;

  bool _isListening = false;
  bool _speechReady = false;
  bool _geminiReady = false;

  String _text = '';
  String _status = 'THORFIN is starting...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _initTts();
    await _initGemini();
    await _initSpeech();

    if (mounted) {
      setState(() {
        _status = _geminiReady
            ? 'THORFIN is ready'
            : 'Gemini is not connected';
      });
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initGemini() async {
    if (_apiKey.isEmpty) {
      _geminiReady = false;
      return;
    }

    try {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        systemInstruction: Content.text(
          '''
You are THORFIN, Juwel's personal AI assistant.

Personality:
- Friendly
- Practical
- Clear
- Honest
- Talk like a helpful bhai
- Keep normal answers reasonably short
- You can understand Hinglish, Hindi and English

Important:
If the user asks to open an Android app, return ONLY one of these commands:
ACTION:YOUTUBE
ACTION:CHROME
ACTION:CAMERA
ACTION:MAPS
ACTION:SETTINGS

For normal questions, answer normally.
Do not use ACTION commands for normal questions.
''',
        ),
      );

      _chat = _model!.startChat();
      _geminiReady = true;
    } catch (_) {
      _geminiReady = false;
    }
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;

        if (status == 'listening') {
          setState(() {
            _isListening = true;
            _status = 'Listening...';
          });
        } else if (status == 'done') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _isListening = false;
          _status = 'Voice error';
        });
      },
    );
  }

  Future<void> _speak(String message) async {
    if (message.trim().isEmpty) return;

    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> _openYouTube() async {
    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: Uri.encodeFull('https://www.youtube.com'),
        package: 'com.google.android.youtube',
      );

      final canOpen = await intent.canResolveActivity();

      if (canOpen == true) {
        await _speak('YouTube khol raha hoon');
        await intent.launch();
      } else {
        await _speak('YouTube app nahi mili');
      }
    } catch (_) {
      await _speak('YouTube open nahi ho paya');
    }
  }

  Future<void> _openChrome() async {
    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: Uri.encodeFull('https://www.google.com'),
        package: 'com.android.chrome',
      );

      final canOpen = await intent.canResolveActivity();

      if (canOpen == true) {
        await _speak('Chrome khol raha hoon');
        await intent.launch();
      } else {
        await _speak('Chrome app nahi mili');
      }
    } catch (_) {
      await _speak('Chrome open nahi ho paya');
    }
  }

  Future<void> _openCamera() async {
    try {
      final intent = AndroidIntent(
        action: 'android.media.action.IMAGE_CAPTURE',
      );

      await _speak('Camera khol raha hoon');
      await intent.launch();
    } catch (_) {
      await _speak('Camera open nahi ho paya');
    }
  }

  Future<void> _openMaps() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'geo:0,0',
        package: 'com.google.android.apps.maps',
      );

      final canOpen = await intent.canResolveActivity();

      if (canOpen == true) {
        await _speak('Maps khol raha hoon');
        await intent.launch();
      } else {
        await _speak('Maps app nahi mili');
      }
    } catch (_) {
      await _speak('Maps open nahi ho paya');
    }
  }

  Future<void> _openSettings() async {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.SETTINGS',
      );

      await _speak('Settings khol raha hoon');
      await intent.launch();
    } catch (_) {
      await _speak('Settings open nahi ho paya');
    }
  }

  Future<void> _executeAction(String action) async {
    switch (action) {
      case 'ACTION:YOUTUBE':
        await _openYouTube();
        break;

      case 'ACTION:CHROME':
        await _openChrome();
        break;

      case 'ACTION:CAMERA':
        await _openCamera();
        break;

      case 'ACTION:MAPS':
        await _openMaps();
        break;

      case 'ACTION:SETTINGS':
        await _openSettings();
        break;

      default:
        await _speak('Command samajh nahi aayi bhai');
    }
  }

  Future<void> _askGemini(String userText) async {
    if (!_geminiReady || _chat == null) {
      await _speak(
        'Gemini abhi connected nahi hai bhai',
      );
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _status = 'Thinking...';
        });
      }

      final response = await _chat!.sendMessage(
        Content.text(userText),
      );

      final answer = response.text?.trim() ?? '';

      if (answer.isEmpty) {
        await _speak('Gemini ne koi answer nahi diya');
        return;
      }

      if (answer.startsWith('ACTION:')) {
        await _executeAction(answer);
        return;
      }

      if (mounted) {
        setState(() {
          _status = 'THORFIN';
        });
      }

      await _speak(answer);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Gemini error';
        });
      }

      await _speak(
        'Bhai Gemini se connection nahi ho paya',
      );
    }
  }

  Future<void> _processCommand(String command) async {
    final text = command.trim();

    if (text.isEmpty) {
      await _speak('Kuch sunai nahi diya bhai');
      return;
    }

    final lower = text.toLowerCase();

    if (lower == 'stop' ||
        lower.contains('band karo') ||
        lower.contains('band kar do') ||
        lower.contains('ruk jao')) {
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

    await _askGemini(text);
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      await _initSpeech();
    }

    if (!_speechReady) {
      await _speak(
        'Speech recognition ready nahi hai',
      );
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
            _status = 'Processing...';
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                ),
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
              _isListening
                  ? 'Tap to stop'
                  : 'Tap to speak',
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
