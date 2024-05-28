// import 'dart:async';

// import 'package:ai_chat/main.dart';
// import 'package:ai_chat/services/gemini_service.dart';
// import 'package:ai_chat/services/speaking_servive.dart';
// import 'package:rxdart/rxdart.dart';
// import 'package:speech_to_text/speech_recognition_error.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
// import 'package:speech_to_text/speech_to_text.dart';

// class ListeningService {
//   final SpeechToText _speechToText = SpeechToText();
//   bool _speechEnabled = false;
//   bool _isProcessing = false;
//   bool _isRequesting = false;
//   final speechSubject = BehaviorSubject<String>();

//   final SpeakingService speakingService = getIt<SpeakingService>();
//   final GeminiService gemini = getIt<GeminiService>();

//   Stream<String> get speechStream => speechSubject.stream
//       .distinct()
//       .debounceTime(const Duration(milliseconds: 3000));

//   Future<void> initSpeech() async {
//     _speechEnabled =
//         await _speechToText.initialize(onError: _onError, onStatus: _onStatus);
//   }

//   void _onStatus(String status) async {
//     logger.i('onStatus: $status');
//     logger.i("Speech Status: ${status}\n");
//     if (status == SpeechToText.doneStatus) {
//       logger.i('listener stopped');
//       _processAndSpeak();
//     }
//   }

//   void _onError(SpeechRecognitionError errorNotification) {
//     logger.i("Error: ${errorNotification.errorMsg}\n");
//   }

//   Future<void> startListening() async {
//     logger.i("Bắt đầu lắng nghe");
//     _isProcessing = true;
//     if (!_speechEnabled) {
//       print("Nhận diện tiếng nói không khả dụng.");
//       return;
//     }

//     if (!_speechToText.isListening) {
//       await _speechToText.listen(onResult: _onSpeechResult);
//     }
//   }

//   void _onSpeechResult(SpeechRecognitionResult result) {
//     String recognizedWords = result.recognizedWords;
//     speechSubject.add(recognizedWords);
//     logger.i("Đang nghe: $recognizedWords");
//   }

//   void dispose() {
//     speechSubject.close();
//     _speechToText.stop();
//   }

// void stopListening() {
//   logger.i("Ngừng lắng nghe");
//   _isProcessing = false;
//   _speechToText.cancel();
//   speechSubject.add('');
// }

//   void _processAndSpeak() async {
//     if (_isRequesting) {
//       return;
//     }

//     _isRequesting = true;
//     String lastRecognizedWords = speechSubject.value;

//     if (lastRecognizedWords.isNotEmpty &&
//         lastRecognizedWords.toUpperCase() != "STOP") {
//       chatStream.sink.add([
//         ...chatStream.value,
//         {"role": "User", "text": lastRecognizedWords},
//       ]);

//       try {
//         final response = await gemini.generateFromText(lastRecognizedWords);
//         logger.i("Gemini: ${response.text}, $lastRecognizedWords");

//         speakingService.speak(response.text);

//         chatStream.sink.add([
//           ...chatStream.value,
//           {"role": "Gemini", "text": response.text},
//         ]);
//       } catch (error) {
//         speakingService.speak("Đã xảy ra lỗi! Vui lòng thử lại.");
//         print("Lỗi: ${error.toString()}");
//       } finally {
//         _isRequesting = false;
//       }
//     } else {
//       stopListening();
//     }
//   }
// }

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
      await _speechToText.listen(onResult: _onSpeechResult);
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
    }
  }

  void dispose() {
    logger.i("Disposing ListeningService");
    _speechToText.stop();
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
    speechSubject.add('');
  }
}
