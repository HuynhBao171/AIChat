import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_chat/main.dart';
import 'package:ai_chat/services/gemini_service.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

Map<String, dynamic> baseParams = {
  'model': 'nova-2-general',
  'detect_language': true,
  'filler_words': false,
  'punctuation': true,
  'encoding': 'aac',
};

final apiKey = dotenv.get('DEEPGRAM_API_KEY');
Deepgram deepgram = Deepgram(apiKey, baseQueryParams: baseParams);

class DeepgramService {
  Timer? _debounceTimer;
  final GeminiService gemini = getIt<GeminiService>();
  bool _isProcessing = false;

  final mic = AudioRecorder();

  void startStream() async {
    textStream.add("");
    await mic.hasPermission();

    final audioStream = await mic.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));

    print('Recording started...');

    final liveParams = {
      'detect_language': false,
      'language': 'en',
      'encoding': 'linear16',
      'sample_rate': 16000,
    };

    final stream = deepgram.transcribeFromLiveAudioStream(audioStream,
        queryParams: liveParams);

    stream.listen((res) {
      print(res.transcript);
      if (res.transcript.isNotEmpty) {
        textStream.sink.add(res.transcript);
        _restartDebounceTimer();
      }
    });
  }

  void _restartDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      logger.i("Debounce timer expired, processing and speaking...");
      _processAndSpeak(textStream.stream.value);
    });
  }

  Future<void> _processAndSpeak(String recognizedWords) async {
    logger.i("Processing and speaking, recognized words: $recognizedWords");
    stopStream();
    if (recognizedWords.isNotEmpty && recognizedWords.toUpperCase() != "STOP") {
      if (_isProcessing) {
        logger.i("Already processing, skipping this request");
        return;
      }
      _isProcessing = true;
      logger.i("Processing request: $recognizedWords");

      chatStream.sink.add([
        ...chatStream.value,
        {"role": "User", "text": recognizedWords},
      ]);

      try {
        final response = await gemini.generateFromText(recognizedWords);
        logger.i("Gemini response: ${response.text}");

        speakFromText(response.text);

        chatStream.sink.add([
          ...chatStream.value,
          {"role": "Gemini", "text": response.text},
        ]);
      } catch (error) {
        logger.e("Error processing request: $error");
        speakFromText("Đã xảy ra lỗi! Vui lòng thử lại.");
        print("Lỗi: ${error.toString()}");
      } finally {
        textStream.sink.add("");
        _isProcessing = false;
        logger.i("Processing complete");
      }
    } else if (recognizedWords.toUpperCase() == "STOP") {
      logger.i("Stop command received, stopping listening");
      stopStream();
    } else {
      logger.i("Recognized words empty");
    }
  }

  void stopStream() async {
    print('Recording stopped');
    await mic.stop();
    _debounceTimer?.cancel(); // Hủy timer khi dừng stream
  }

  void speakFromText(String text) async {
    Deepgram deepgramTTS = Deepgram(apiKey, baseQueryParams: {
      'model': 'aura-asteria-en',
      'encoding': "linear16",
      'container': "wav",
    });
    final res = await deepgramTTS.speakFromText(text);
    int random = DateTime.now().millisecondsSinceEpoch;
    final path = await saveDataToFile("$random.wav", res.data);
    final player = AudioPlayer();

    player.onPlayerComplete.listen((event) async {
      logger.i('Audio playback completed. Deleting file: $path');
      try {
        await File(path).delete();
        logger.i('File deleted successfully.');

        startStream();
      } catch (e) {
        logger.e('Error deleting file: $e');
      }
    });

    await player.play(DeviceFileSource(path));
  }
}

Future<String> saveDataToFile(String filename, Uint8List data) async {
  final path = await getLocalFilePath(filename);
  await File(path).writeAsBytes(data);
  return path;
}

Future<String> getLocalFilePath(String filename) async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  String appDocPath = appDocDir.path;
  return '$appDocPath/$filename';
}
