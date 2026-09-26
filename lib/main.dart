import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() => runApp(const ThorfinApp());

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
  static const String _apiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
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

  Future<void> _setup() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _setupSpeech();
    _setupGemini();
    if (mounted) setState(() {});
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _setupSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'listening') {
            setState(() {
              _isListening = true;
              _status = 'Listening...';
            });
          } else if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _status = 'Mic error';
          });
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
  }

  void _setupGemini() {
    if (_apiKey.trim().isEmpty) {
      _model = null;
      _chat = null;
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.text('''
You are THORFIN, Juwel's personal AI assistant.

Be friendly, practical, clear and concise. Talk like a bhai.
Understand Hinglish, Hindi and English.

When the user wants to open an Android app, return ONLY one exact command:
ACTION:YOUTUBE
ACTION:CHROME
ACTION:CAMERA
ACTION:MAPS
ACTION:SETTINGS

Examples:
YouTube kholo -> ACTION:YOUTUBE
Chrome open karo -> ACTION:CHROME
Camera kholo -> ACTION:CAMERA
Maps kholo -> ACTION:MAPS
Settings kholo -> ACTION:SETTINGS

For normal questions, answer normally.
Do not put ACTION commands in markdown.
Do not add extra text to an ACTION response.
'''),
    );

    _chat = _model!.startChat();
  }

  Future<void> _startListening() async {
    if (_isThinking) return;

    if (!_speechAvailable) await _setupSpeech();

    if (!_speechAvailable) {
      if (mounted) {
        setState(() => _status = 'Speech recognition unavailable');
      }
      await _speak('Speech recognition is not available.');
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
        if (!mounted) return;

        setState(() => _heardText = result.recognizedWords);

        if (result.finalResult &&
            result.recognizedWords.trim().isNotEmpty) {
          await _speech.stop();
          if (mounted) setState(() => _isListening = false);
          await _processCommand(result.recognizedWords.trim());
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  Future<void> _processCommand(String text) async {
    if (text.trim().isEmpty) return;

    if (mounted) {
      setState(() {
        _isThinking = true;
        _status = 'Thinking...';
      });
    }

    final lower = text.toLowerCase();

    if (_containsAny(lower, [
      'youtube kholo',
      'youtube open',
      'youtube chalao',
      'youtube khol',
      'open youtube',
    ])) {
      await _executeAction('ACTION:YOUTUBE');
      return;
    }

    if (_containsAny(lower, [
      'chrome kholo',
      'chrome open',
      'chrome khol',
      'open chrome',
    ])) {
      await _executeAction('ACTION:CHROME');
      return;
    }

    if (_containsAny(lower, [
      'camera kholo',
      'camera open',
      'camera khol',
      'open camera',
    ])) {
      await _executeAction('ACTION:CAMERA');
      return;
    }

    if (_containsAny(lower, [
      'maps kholo',
      'maps open',
      'map kholo',
      'maps khol',
      'open maps',
    ])) {
      await _executeAction('ACTION:MAPS');
      return;
    }

    if (_containsAny(lower, [
      'settings kholo',
      'settings open',
      'setting kholo',
      'settings khol',
      'open settings',
    ])) {
      await _executeAction('ACTION:SETTINGS');
      return;
    }

    await _askGemini(text);
  }

  bool _containsAny(String text, List<String> words) =>
      words.any(text.contains);

  Future<void> _askGemini(String text) async {
    if (_chat == null) {
      if (mounted) {
        setState(() {
          _isThinking = false;
          _status = 'Gemini is not connected';
        });
      }
      await _speak('Gemini is not connected.');
      return;
    }

    try {
      final response = await _chat!.sendMessage(Content.text(text));
      final answer = response.text?.trim() ?? '';

      if (answer.isEmpty) {
        if (mounted) {
          setState(() {
            _isThinking = false;
            _status = 'No response';
          });
        }
        await _speak('I could not get a response.');
        return;
      }

      if (answer.startsWith('ACTION:')) {
        await _executeAction(answer);
        return;
      }

      if (!mounted) return;

      setState(() {
        _replyText = answer;
        _status = 'Done';
        _isThinking = false;
      });

      await _speak(answer);
    } catch (e) {
      if (!mounted) return;

      final errorText = e.toString();
      setState(() {
        _isThinking = false;
        _status = 'Gemini error';
        _replyText = errorText.length > 1200
            ? errorText.substring(0, 1200)
            : errorText;
      });

      await _speak('Gemini error. Check the message on screen.');
    }
  }

  Future<void> _executeAction(String action) async {
    switch (action.trim().toUpperCase()) {
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
        if (mounted) {
          setState(() {
            _status = 'Unknown action';
            _isThinking = false;
          });
        }
        await _speak('I do not know that action yet.');
    }
  }

  Future<void> _openYouTube() async {
    try {
      await AndroidIntent(
        action: 'action_view',
        data: Uri.encodeFull('https://www.youtube.com'),
        package: 'com.google.android.youtube',
      ).launch();

      if (mounted) {
        setState(() {
          _status = 'Opening YouTube...';
          _isThinking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Could not open YouTube';
          _isThinking = false;
        });
      }
      await _speak('YouTube could not be opened.');
    }
  }

  Future<void> _openChrome() async {
    try {
      await AndroidIntent(
        action: 'action_view',
        data: Uri.encodeFull('https://www.google.com'),
        package: 'com.android.chrome',
      ).launch();

      if (mounted) {
        setState(() {
          _status = 'Opening Chrome...';
          _isThinking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Could not open Chrome';
          _isThinking = false;
        });
      }
      await _speak('Chrome could not be opened.');
    }
  }

  Future<void> _openCamera() async {
    try {
      await AndroidIntent(
        action: 'android.media.action.IMAGE_CAPTURE',
      ).launch();

      if (mounted) {
        setState(() {
          _status = 'Opening Camera...';
          _isThinking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Could not open Camera';
          _isThinking = false;
        });
      }
      await _speak('Camera could not be opened.');
    }
  }

  Future<void> _openMaps() async {
    try {
      await AndroidIntent(
        action: 'action_view',
        data: Uri.encodeFull('geo:0,0?q=Dhaka'),
        package: 'com.google.android.apps.maps',
      ).launch();

      if (mounted) {
        setState(() {
          _status = 'Opening Maps...';
          _isThinking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Could not open Maps';
          _isThinking = false;
        });
      }
      await _speak('Maps could not be opened.');
    }
  }

  Future<void> _openSettings() async {
    try {
      await AndroidIntent(
        action: 'android.settings.SETTINGS',
      ).launch();

      if (mounted) {
        setState(() {
          _status = 'Opening Settings...';
          _isThinking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'Could not open Settings';
          _isThinking = false;
        });
      }
      await _speak('Settings could not be opened.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _apiKey.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'THORFIN AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151B23),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      size: 65,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Hello Juwel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    connected ? _status : 'Gemini is not connected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: connected
                          ? Colors.white70
                          : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_heardText.isNotEmpty)
                    _messageBox('You: $_heardText'),
                  if (_replyText.isNotEmpty)
                    _messageBox('THORFIN: $_replyText'),
                  GestureDetector(
                    onTap: _isThinking ? null : _startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? Colors.redAccent
                            : const Color(0xFF1E88E5),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: _isListening ? 25 : 12,
                            spreadRadius: _isListening ? 4 : 1,
                            color: _isListening
                                ? Colors.redAccent
                                : Colors.blueAccent,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isListening
                        ? 'Listening...'
                        : _isThinking
                            ? 'Thinking...'
                            : 'Tap to speak',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    connected
                        ? 'Gemini connected'
                        : 'Gemini API key missing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: connected
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151B23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
