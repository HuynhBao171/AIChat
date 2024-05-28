import 'package:ai_chat/main.dart';
import 'package:ai_chat/services/listening_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SpeakingService {
  final FlutterTts flutterTts = FlutterTts();

  Future initTts() async {
    await flutterTts.setLanguage("en-US");
  }

  Future<void> speak(String text) async {
    try {
      await flutterTts.speak(text);
      flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers
          ],
          IosTextToSpeechAudioMode.voicePrompt);
      flutterTts.setCompletionHandler(() {
        getIt<ListeningService>().startListening();
      });
    } catch (e) {
      print('Lỗi phát âm: $e');
    }
  }
}
