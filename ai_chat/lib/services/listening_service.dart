import 'dart:async';

import 'package:ai_chat/main.dart';
import 'package:ai_chat/services/gemini_service.dart';
import 'package:ai_chat/services/speaking_servive.dart';
import 'package:rxdart/rxdart.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ListeningService {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isProcessed = true;
  final speechSubject = BehaviorSubject<String>();
  DateTime? _lastSpeechTime;

  final SpeakingService speakingService = getIt<SpeakingService>();
  final GeminiService gemini = getIt<GeminiService>();

  Stream<String> get speechStream => speechSubject.stream;

  Future<void> initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
  }

  Future<void> startListening() async {
    logger.i("Bắt đầu lắng nghe");
    _isProcessed = true;
    if (!_speechEnabled) {
      print("Nhận diện tiếng nói không khả dụng.");
      return;
    }

    if (!_speechToText.isListening) {
      await _speechToText.listen(onResult: _onSpeechResult);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    speechSubject.add(result.recognizedWords);
    logger.i("Đang nghe: ${result.recognizedWords}");
    _lastSpeechTime = DateTime.now();

    if ((result.finalResult && _isProcessed) ||
        (_lastSpeechTime != null &&
            DateTime.now().difference(_lastSpeechTime!).inSeconds >= 2)) {
      _speechToText.stop(); // Dừng lắng nghe khi kết thúc câu
      _isProcessed = false;

      String recognizedWords = result.recognizedWords;

      if (recognizedWords != '' && recognizedWords.toUpperCase() != "STOP") {
        chatStream.sink.add([
          ...chatStream.value,
          {"role": "User", "text": recognizedWords},
        ]);

        gemini.generateFromText(recognizedWords).then((value) {
          logger.i("Gemini: ${value.text}, $recognizedWords");
          speakingService.speak(value.text);
          chatStream.sink.add([
            ...chatStream.value,
            {"role": "Gemini", "text": value.text},
          ]);
        }).catchError((error, stackTrace) {
          speakingService.speak("Đã xảy ra lỗi! Vui lòng thử lại.");
          print("Lỗi: ${error.toString()}");
        });
      }
      stopListening();
    }
  }

  void dispose() {
    speechSubject.close();
    _speechToText.stop();
  }

  void stopListening() {
    logger.i("Ngừng lắng nghe");
    _speechToText.stop();
  }
}
