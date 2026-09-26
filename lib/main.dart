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
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0F14),
          elevation: 0,
          centerTitle: true,
        ),
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
  // ============================================================
  // GEMINI API KEY
  // ============================================================
  // DO NOT put the real API key here.
  // Codemagic will provide it through --dart-define.
  // ============================================================

  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  GenerativeModel? _model;
  ChatSession? _chat;

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isThinking = false;

  String _status = 'THORFIN is ready.';
  String _heardText = '';
  String _replyText = '';

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    _setup();
  }

  // ============================================================
  // INITIAL SETUP
  // ============================================================

  Future<void> _setup() async {
    await _setupTts();
    await _setupSpeech();
    _setupGemini();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // TEXT TO SPEECH
  // ============================================================

  Future<void> _setupTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    await _tts.stop();
    await _tts.speak(text);
  }

  // ============================================================
  // SPEECH TO TEXT
  // ============================================================

  Future<void> _setupSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) {
            return;
          }

          if (status == 'listening') {
            setState(() {
              _isListening = true;
              _status = 'Listening...';
            });
          } else if (status == 'notListening' ||
              status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isListening = false;
            _status = 'Mic error';
          });
        },
      );
    } catch (e) {
      _speechAvailable = false;
    }
  }

  // ============================================================
  // GEMINI SETUP
  // ============================================================

  void _setupGemini() {
    if (_apiKey.trim().isEmpty) {
      _model = null;
      _chat = null;
      return;
    }

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
- Helpful
- Talk like a bhai
- Understand Hinglish, Hindi and English
- Keep normal answers concise unless more detail is needed

IMPORTANT ACTION RULE:

When the user wants to open an Android app, return ONLY one
of these exact commands:

ACTION:YOUTUBE
ACTION:CHROME
ACTION:CAMERA
ACTION:MAPS
ACTION:SETTINGS

Examples:

User: YouTube kholo
Assistant: ACTION:YOUTUBE

User: Chrome open karo
Assistant: ACTION:CHROME

User: Camera kholo
Assistant: ACTION:CAMERA

User: Maps kholo
Assistant: ACTION:MAPS

User: Settings kholo
Assistant: ACTION:SETTINGS

For normal questions, answer normally.

Do not put ACTION commands inside markdown.
Do not add extra text to an ACTION response.
''',
      ),
    );

    _chat = _model!.startChat();
  }

  // ============================================================
  // START LISTENING
  // ============================================================

  Future<void> _startListening() async {
    if (_isThinking) {
      return;
    }

    if (!_speechAvailable) {
      await _setupSpeech();
    }

    if (!_speechAvailable) {
      if (mounted) {
        setState(() {
          _status = 'Speech recognition unavailable';
        });
      }

      await _speak(
        'Speech recognition is not available.',
      );

      return;
    }

    await _tts.stop();

    if (mounted) {
      setState(() {
        _isListening = true;
        _status = 'Listening...';
        _heardText = '';
        _replyText = '';
      });
    }

    await _speech.listen(
      onResult: (result) async {
        if (!mounted) {
          return;
        }

        setState(() {
          _heardText = result.recognizedWords;
        });

        if (result.finalResult &&
            result.recognizedWords.trim().isNotEmpty) {
          await _speech.stop();

          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }

          await _processCommand(
            result.recognizedWords.trim(),
          );
