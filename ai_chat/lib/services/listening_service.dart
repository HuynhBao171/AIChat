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
  Timer? _debounceTimer;
  bool _isProcessing = false;
  final speechSubject = BehaviorSubject<String>();

  final SpeakingService speakingService = getIt<SpeakingService>();
  final GeminiService gemini = getIt<GeminiService>();

  Stream<String> get speechStream => speechSubject.stream;

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
    _recognizedWords = result.recognizedWords;
    speechSubject.add(_recognizedWords); 
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
    speechSubject.close();
  }

  Future<void> _processAndSpeak() async {
    _debounceTimer?.cancel();

    if (_recognizedWords.isNotEmpty &&
        _recognizedWords.toUpperCase() != "STOP") {
      if (_isProcessing) {
        return;
      }
      _isProcessing = true;

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
        _isProcessing = false;
        startListening(); 
      }
    } else {
      startListening(); 
    }
  }

  void stopListening() {
    logger.i("Ngừng lắng nghe");
    _speechToText.cancel();
    speechSubject.add('');
  }
}
