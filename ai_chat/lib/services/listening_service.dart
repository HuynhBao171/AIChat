import 'dart:async';

import 'package:ai_chat/main.dart';
import 'package:ai_chat/services/gemini_service.dart';
import 'package:ai_chat/services/speaking_servive.dart';
import 'package:rxdart/rxdart.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ListeningService {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _recognizedWords = '';
  bool _isProcessing = false;
  final speechSubject = BehaviorSubject<String>();
  Timer? _debounceTimer;

  final SpeakingService speakingService = getIt<SpeakingService>();
  final GeminiService gemini = getIt<GeminiService>();

  Stream<String> get speechStream => speechSubject.stream;

  Future<void> initSpeech() async {
    logger.i('Initializing speech');
    _speechEnabled = await _speechToText.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
    logger
        .i('Speech initialization complete: _speechEnabled = $_speechEnabled');
  }

  void _onStatus(String status) {
    logger.i('onStatus: $status');
  }

  void _onError(SpeechRecognitionError errorNotification) {
    logger.e("Speech Recognition Error: ${errorNotification.errorMsg}");
  }

  Future<void> startListening() async {
    logger.i("Starting listening");
    if (!_speechEnabled) {
      logger.w("Speech recognition is not available");
      return;
    }

    if (!_speechToText.isListening) {
      logger.i("Start listening...");

      await _speechToText.listen(
          onResult: _onSpeechResult,
          pauseFor: const Duration(seconds: 5),
          // listenFor: const Duration(seconds: 5),
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.deviceDefault,
            partialResults: true,
            autoPunctuation: true,
          ));
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (speakingService.isSpeaking) {
      return;
    }
    _recognizedWords = result.recognizedWords;
    speechSubject.add(_recognizedWords);
    logger.i(
        "Recognized words: $_recognizedWords, Final Result: ${result.finalResult}");

    if (result.finalResult) {
      logger.i("Final result received, processing and speaking...");
      _processAndSpeak();
    } else {
      _restartDebounceTimer();
    }
  }

  void _restartDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      logger.i("Debounce timer expired, processing and speaking...");
      _processAndSpeak();
    });
  }

  void dispose() {
    logger.i("Disposing ListeningService");
    _speechToText.stop();
    _debounceTimer?.cancel();
    speechSubject.close();
  }

  Future<void> _processAndSpeak() async {
    logger.i("Processing and speaking, recognized words: $_recognizedWords");

    if (_recognizedWords.isNotEmpty &&
        _recognizedWords.toUpperCase() != "STOP") {
      if (_isProcessing) {
        logger.i("Already processing, skipping this request");
        return;
      }
      _isProcessing = true;
      logger.i("Processing request: $_recognizedWords");

      chatStream.sink.add([
        ...chatStream.value,
        {"role": "User", "text": _recognizedWords},
      ]);

      try {
        final response = await gemini.generateFromText(_recognizedWords);
        logger.i("Gemini response: ${response.text}");

        speakingService.speak(response.text);

        chatStream.sink.add([
          ...chatStream.value,
          {"role": "Gemini", "text": response.text},
        ]);
      } catch (error) {
        logger.e("Error processing request: $error");

        speakingService.speak("Đã xảy ra lỗi! Vui lòng thử lại.");
        print("Lỗi: ${error.toString()}");
      } finally {
        _recognizedWords = '';
        _isProcessing = false;
        logger.i("Processing complete, starting listening again");

        startListening();
      }
    } else if (_recognizedWords.toUpperCase() == "STOP") {
      logger.i("Stop command received, stopping listening");
      stopListening();
    } else {
      logger.i("Recognized words empty, starting listening again");
      startListening();
    }
  }

  void stopListening() {
    logger.i("Stopping listening");
    _speechToText.cancel();
    _debounceTimer?.cancel();
    speechSubject.add('');
  }
}
