import 'dart:async';

import 'package:ai_chat/main.dart';
import 'package:ai_chat/services/gemini_service.dart';
import 'package:ai_chat/services/speaking_servive.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ListeningService {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _recognizedWords = '';
  Timer? _debounceTimer;

  final SpeakingService speakingService = getIt<SpeakingService>();
  final GeminiService gemini = getIt<GeminiService>();

  Future<void> initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
  }

  void _onStatus(String status) {
    logger.i('onStatus: $status');
  }

  void _onError(SpeechRecognitionError errorNotification) {
    logger.i("Error: ${errorNotification.errorMsg}\n");
  }

  Future<void> startListening() async {
    logger.i("Bắt đầu lắng nghe");
    if (!_speechEnabled) {
      print("Nhận diện tiếng nói không khả dụng.");
      return;
    }

    if (!_speechToText.isListening) {
      await _speechToText.listen(onResult: _onSpeechResult);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _recognizedWords += result.recognizedWords;
    logger.i("Đang nghe: $_recognizedWords");

    if (result.finalResult) {
      _processAndSpeak();
    } else {
      _restartDebounceTimer();
    }
  }

  void _restartDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), _processAndSpeak);
  }

  void dispose() {
    _speechToText.stop();
    _debounceTimer?.cancel();
  }

  Future<void> _processAndSpeak() async {
    _debounceTimer?.cancel();

    if (_recognizedWords.isNotEmpty && _recognizedWords.toUpperCase() != "STOP") {
      chatStream.sink.add([
        ...chatStream.value,
        {"role": "User", "text": _recognizedWords},
      ]);

      try {
        final response = await gemini.generateFromText(_recognizedWords);
        logger.i("Gemini: ${response.text}, $_recognizedWords");

        speakingService.speak(response.text);

        chatStream.sink.add([
          ...chatStream.value,
          {"role": "Gemini", "text": response.text},
        ]);
      } catch (error) {
        speakingService.speak("Đã xảy ra lỗi! Vui lòng thử lại.");
        print("Lỗi: ${error.toString()}");
      } finally {
        _recognizedWords = '';
        startListening(); // Lắng nghe tiếp câu nói mới
      }
    } else {
      startListening(); // Lắng nghe tiếp câu nói mới
    }
  }
}