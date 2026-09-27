import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:android_intent_plus/android_intent.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() => runApp(const ThorfinApp());

class ThorfinApp extends StatelessWidget {
  const ThorfinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'THORFIN',
      theme: ThemeData.dark(useMaterial3: true),
      home: const ThorfinHome(),
    );
  }
}

class ThorfinHome extends StatefulWidget {
  const ThorfinHome({super.key});

  @override
  State<ThorfinHome> createState() => _ThorfinHomeState();
}

class _ThorfinHomeState extends State<ThorfinHome>
    with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
  GenerativeModel? _model;
  ChatSession? _chat;

  bool _isListening = false;
  bool _isBusy = false;
  bool _geminiReady = false;

  String _recognizedText = '';
  String _message = 'Ready when you are.';
  String _status = 'Tap the orb to speak';

  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _initialize();
  }

  Future<void> _initialize() async {
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.7);
    await _tts.setPitch(1.0);

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _status = 'Microphone error';
        });
      },
    );

    if (_apiKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _geminiReady = false;
        _status = 'API key missing';
      });
      return;
    }

    try {
      _model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: _apiKey,
        systemInstruction: Content.text(
          '''
You are THORFIN, Juwel's personal AI assistant.
Be friendly, practical, clear and helpful. Understand Hinglish,
Hindi and English. Keep normal answers reasonably short.

For clear Android app-opening requests, return ONLY one exact command:
ACTION:YOUTUBE
ACTION:CHROME
ACTION:CAMERA
ACTION:MAPS
ACTION:SETTINGS

For everything else, answer normally.
''',
        ),
      );
      _chat = _model!.startChat();

      if (!mounted) return;
      setState(() {
        _geminiReady = available;
        _status = available ? 'THORFIN online' : 'Microphone unavailable';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _geminiReady = false;
        _status = 'AI setup error';
        _message = 'AI setup error: $e';
      });
    }
  }

  Future<void> _startListening() async {
    if (_isBusy) return;

    if (!_speech.isAvailable) {
      final ok = await _speech.initialize();
      if (!ok) {
        setState(() => _status = 'Speech recognition unavailable');
        return;
      }
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _message = 'Listening...';
      _status = 'Speak naturally';
    });

    await _speech.listen(
      onResult: (result) async {
        if (!mounted) return;
        setState(() => _recognizedText = result.recognizedWords);

        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          final text = result.recognizedWords.trim();
          await _speech.stop();
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _status = 'Thinking...';
          });
          await _processCommand(text);
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _status = 'Tap the orb to speak';
    });
  }

  Future<void> _processCommand(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isBusy = true;
      _recognizedText = text;
      _message = 'Thinking...';
      _status = 'Processing';
    });

    final lower = text.toLowerCase().trim();

    if (_containsAny(lower, [
      'youtube kholo', 'youtube open', 'open youtube', 'youtube khol do'
    ])) {
      await _openYouTube();
      await _finishAction('YouTube opened');
      return;
    }

    if (_containsAny(lower, [
      'chrome kholo', 'chrome open', 'open chrome', 'chrome khol do'
    ])) {
      await _openChrome();
      await _finishAction('Chrome opened');
      return;
    }

    if (_containsAny(lower, [
      'camera kholo', 'camera open', 'open camera', 'camera khol do'
    ])) {
      await _openCamera();
      await _finishAction('Camera opened');
      return;
    }

    if (_containsAny(lower, [
      'maps kholo', 'maps open', 'open maps', 'map kholo', 'google maps kholo'
    ])) {
      await _openMaps();
      await _finishAction('Maps opened');
      return;
    }

    if (_containsAny(lower, [
      'settings kholo', 'settings open', 'open settings', 'setting kholo'
    ])) {
      await _openSettings();
      await _finishAction('Settings opened');
      return;
    }

    if (_containsAny(lower, [
      'stop', 'band ho jao', 'band ho ja', 'chup', 'quiet'
    ])) {
      await _tts.stop();
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _message = 'Okay.';
        _status = 'Tap the orb to speak';
      });
      return;
    }

    if (_chat == null || !_geminiReady) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _message = 'AI is unavailable. Check the API configuration.';
        _status = 'Offline';
      });
      return;
    }

    try {
      final response = await _chat!.sendMessage(Content.text(text));
      final reply = response.text?.trim();

      if (reply == null || reply.isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      if (reply.contains('ACTION:YOUTUBE')) {
        await _openYouTube();
        await _finishAction('YouTube opened');
        return;
      }
      if (reply.contains('ACTION:CHROME')) {
        await _openChrome();
        await _finishAction('Chrome opened');
        return;
      }
      if (reply.contains('ACTION:CAMERA')) {
        await _openCamera();
        await _finishAction('Camera opened');
        return;
      }
      if (reply.contains('ACTION:MAPS')) {
        await _openMaps();
        await _finishAction('Maps opened');
        return;
      }
      if (reply.contains('ACTION:SETTINGS')) {
        await _openSettings();
        await _finishAction('Settings opened');
        return;
      }

      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _message = reply;
        _status = 'THORFIN online';
      });
      await _speak(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _message = _formatGeminiError(e);
        _status = 'Request failed';
      });
    }
  }

  bool _containsAny(String text, List<String> phrases) => phrases.any(text.contains);

  String _formatGeminiError(Object error) {
    final raw = error.toString();
    return raw.length <= 900
        ? 'Gemini error:\n\n$raw'
        : 'Gemini error:\n\n${raw.substring(0, 900)}...';
  }

  Future<void> _finishAction(String message) async {
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _message = message;
      _status = 'THORFIN online';
    });
    await _speak(message);
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _openYouTube() async {
    await AndroidIntent(
      action: 'action_view',
      data: Uri.encodeFull('https://www.youtube.com'),
      package: 'com.google.android.youtube',
    ).launch();
  }

  Future<void> _openChrome() async {
    await AndroidIntent(
      action: 'action_view',
      data: Uri.encodeFull('https://www.google.com'),
      package: 'com.android.chrome',
    ).launch();
  }

  Future<void> _openCamera() async {
    await AndroidIntent(action: 'android.media.action.IMAGE_CAPTURE').launch();
  }

  Future<void> _openMaps() async {
    await AndroidIntent(
      action: 'action_view',
      data: Uri.encodeFull('geo:0,0?q=Dhaka'),
      package: 'com.google.android.apps.maps',
    ).launch();
  }

  Future<void> _openSettings() async {
    await AndroidIntent(action: 'android.settings.SETTINGS').launch();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF080D16), Color(0xFF05070C), Color(0xFF020307)],
              ),
            ),
          ),
          Positioned(
            top: -150,
            left: MediaQuery.of(context).size.width / 2 - 180,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1688FF).withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        _assistantOrb(),
                        const SizedBox(height: 25),
                        const Text(
                          'THORFIN',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _status,
                          style: TextStyle(
                            fontSize: 14,
                            color: _isListening
                                ? const Color(0xFF5BB7FF)
                                : const Color(0xFF8993A3),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_recognizedText.isNotEmpty)
                          _messageCard(
                            label: 'YOU',
                            text: _recognizedText,
                            icon: Icons.person_outline_rounded,
                          ),
                        if (_recognizedText.isNotEmpty) const SizedBox(height: 12),
                        _messageCard(
                          label: _isBusy ? 'THORFIN • THINKING' : 'THORFIN',
                          text: _message,
                          icon: _isBusy
                              ? Icons.auto_awesome_rounded
                              : Icons.smart_toy_outlined,
                        ),
                        const SizedBox(height: 28),
                        _micButton(),
                        const SizedBox(height: 14),
                        Text(
                          _isListening ? 'Tap to stop' : 'Tap to speak',
                          style: const TextStyle(
                            color: Color(0xFF8993A3),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _onlineChip(),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 5, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF4F5A69)),
                      const SizedBox(width: 6),
                      Text(
                        'Voice powered • Ready to assist',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.28),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: 7,
            bottom: 3,
            child: Opacity(
              opacity: 0.025,
              child: Text(
                'JUWEL',
                style: TextStyle(fontSize: 8, letterSpacing: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF101722),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 21, color: Color(0xFF79C7FF)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THORFIN AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
                SizedBox(height: 2),
                Text(
                  'PERSONAL ASSISTANT',
                  style: TextStyle(fontSize: 9, color: Color(0xFF687486), letterSpacing: 2.2),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1715),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF42E6A4).withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _geminiReady ? const Color(0xFF42E6A4) : const Color(0xFFFF8A80),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _geminiReady ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: _geminiReady ? const Color(0xFF42E6A4) : const Color(0xFFFF8A80),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assistantOrb() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = _isListening ? 1.0 + (_pulse.value * 0.07) : 1.0 + (_pulse.value * 0.018);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 178,
            height: 178,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF1C7CFF), Color(0xFF0D2A53), Color(0xFF09101B)],
                stops: [0.0, 0.48, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? const Color(0xFF249BFF) : const Color(0xFF1268FF))
                      .withOpacity(_isListening ? 0.55 : 0.28),
                  blurRadius: _isListening ? 50 : 34,
                  spreadRadius: _isListening ? 5 : 0,
                ),
              ],
              border: Border.all(color: const Color(0xFF5DB6FF).withOpacity(0.25)),
            ),
            child: Center(
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF07101D),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Icon(
                  _isListening ? Icons.graphic_eq_rounded : Icons.smart_toy_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _messageCard({required String label, required String text, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C121B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.055)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF121D2A),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF7BBFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF697689),
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFFE0E5EC)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _micButton() {
    return GestureDetector(
      onTap: _isListening ? _stopListening : (_isBusy ? null : _startListening),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final extra = _isListening ? 6.0 * _pulse.value : 0.0;
          return Container(
            width: 92 + extra,
            height: 92 + extra,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isListening
                    ? const [Color(0xFFFF5C6C), Color(0xFFE52C4A)]
                    : const [Color(0xFF1DA1FF), Color(0xFF0967E8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? const Color(0xFFFF405A) : const Color(0xFF008DFF))
                      .withOpacity(0.45),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
              size: 40,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _onlineChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1312),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF42E6A4).withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 15, color: Color(0xFF42E6A4)),
          const SizedBox(width: 7),
          Text(
            _geminiReady ? 'AI CORE CONNECTED' : 'AI CORE OFFLINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: _geminiReady ? const Color(0xFF42E6A4) : const Color(0xFFFF8A80),
            ),
          ),
        ],
      ),
    );
  }
}
