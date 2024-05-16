import 'dart:async';

import 'package:ai_chat/models/config/gemini_config.dart';
import 'package:ai_chat/models/config/gemini_safety_settings.dart';
import 'package:ai_chat/models/gemini/gemini.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:rxdart/rxdart.dart';
import 'package:speech_to_text/speech_to_text.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool loading = false;
  List textChat = [];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _controller = ScrollController();

  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;

  final FlutterTts flutterTts = FlutterTts();

  Timer? _speechTimer;

  var _speechStream = BehaviorSubject<String>();

  late final gemini;

  final safety1 = SafetySettings(
      category: SafetyCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
      threshold: SafetyThreshold.BLOCK_ONLY_HIGH);

  final config = GenerationConfig(
      temperature: 0.5,
      maxOutputTokens: 100,
      topP: 1.0,
      topK: 40,
      stopSequences: []);

  @override
  void initState() {
    _initTts();
    gemini = GoogleGemini(safetySettings: [safety1], config: config);
    super.initState();
    // Lời chào từ Gemini
    textChat.add({
      "role": "Gemini",
      "text": "Hello! I'm here to help you.",
    });
    _speak(textChat[0]['text']);
  }

  Future _initTts() async {
    await flutterTts.setLanguage("en-US");
  }

  @override
  void dispose() {
    _speechStream.close();
    _speechToText.stop();
    super.dispose();
  }

  Future _speak(String text) async {
    try {
      _textController.clear();
      await flutterTts.speak(text);
      flutterTts.setCompletionHandler(() {
        _startListening();
      });
    } catch (e) {
      print('Lỗi phát âm: $e');
    }
  }

  void fromText({required String query, required String user}) {
    setState(() {
      loading = true;
      textChat.add({
        "role": user,
        "text": query,
      });
      // _textController.clear();
    });
    scrollToTheEnd();

    gemini.generateFromText(query).then((value) {
      setState(() {
        loading = false;

        textChat.add({
          "role": "Gemini",
          "text": value.text,
        });
      });
      scrollToTheEnd();
      _speak(value.text);
      // _startListening();
    }).catchError((error, stackTrace) {
      setState(() {
        loading = false;
        textChat.add({
          "role": "Gemini",
          "text": error.toString(),
        });
      });
      scrollToTheEnd();
      _speak(error.toString());
    });
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        // _textController.clear();
        _speechToText.listen(
          onResult: (result) {
            _speechStream.add('');
            _speechStream.add(result.recognizedWords);
            if (result.recognizedWords.toUpperCase() == 'STOP') {
              _stopListening();
              return;
            }

            if (_speechTimer != null) _speechTimer?.cancel();
            _speechTimer = Timer(const Duration(seconds: 2), () {
              if (_isListening) {
                _stopListening();
                fromText(query: result.recognizedWords, user: 'User');
              }
            });
          },
        );
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speechToText.stop();

    _speechStream.add('');
    _speechStream.close();
    _speechStream = BehaviorSubject<String>();

    // Dừng timer
    _speechTimer?.cancel();
  }

  void scrollToTheEnd() {
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Main Screen'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _controller,
                itemCount: textChat.length,
                padding: const EdgeInsets.only(bottom: 20),
                itemBuilder: (context, index) {
                  return ListTile(
                    isThreeLine: true,
                    leading: CircleAvatar(
                      child: Text(textChat[index]["role"].substring(0, 1)),
                    ),
                    title: Text(textChat[index]["role"]),
                    subtitle: Text(textChat[index]["text"]),
                  );
                },
              ),
            ),
            Container(
              alignment: Alignment.bottomRight,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: StreamBuilder<String>(
                        stream: _speechStream,
                        builder: (context, snapshot) {
                          _textController.text = snapshot.data ?? '';
                          return TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: "Write a message",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: BorderSide.none),
                              fillColor: Colors.transparent,
                            ),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                          );
                        }),
                  ),
                  IconButton(
                    icon: _isListening
                        ? const Icon(Icons.mic)
                        : const Icon(Icons.mic_off),
                    onPressed: () {
                      _startListening();
                    },
                  ),
                  IconButton(
                    icon: loading
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.send),
                    onPressed: () {
                      fromText(query: _textController.text, user: 'User');
                    },
                  ),
                ],
              ),
            )
          ],
        ));
  }
}
