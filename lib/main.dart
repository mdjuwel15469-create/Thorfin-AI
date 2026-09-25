import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

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
  String _status = 'Tap the mic and speak';

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
          } else if (status == 'done') {
            _status = 'Processing...';
          }
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _isListening = false;
          _status = 'Voice error: ${error.errorMsg}';
        });
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) {
      await _initVoice();
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
          setState(() {
            _isListening = false;
            _status = 'You said:';
          });

          if (_text.trim().isNotEmpty) {
            await _tts.speak('I heard you say $_text');
          }
        }
      },
      listenFor: const Duration(seconds: 20),
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
                  color: _isListening ? Colors.white : Colors.white24,
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
                  color: _isListening ? Colors.red : Colors.white,
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
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
