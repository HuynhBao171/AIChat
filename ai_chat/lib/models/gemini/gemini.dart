import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_chat/models/config/gemini_config.dart';
import 'package:ai_chat/models/config/gemini_safety_settings.dart';
import 'package:ai_chat/models/gemini/gemini_reponse.dart';
import 'package:ai_chat/repository/apis.dart';

/// Google Gemini Main Class.
class GoogleGemini {
  late String apiKey; // The API Key from Google
  GenerationConfig? config;
  List<SafetySettings>? safetySettings;
  String? model = 'gemini-pro'; // The model to use, gemini-pro by default

  GoogleGemini({this.config, this.safetySettings, this.model}) {
    // Đọc API key từ biến môi trường
    apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception("GEMINI_API_KEY environment variable is not set.");
    }
  }

  /// Generate content from a query
  ///
  /// Returns a [Future<String>] with the generated text
  /// If the request fails, it returns the [Error] as a [String] instead
  ///
  Future<GeminiResponse> generateFromText(String query) async {
    String text = '';

    GeminiHttpResponse httpResponse = await apiGenerateText(
      query: query,
      apiKey: apiKey,
      config: config,
      safetySettings: safetySettings,
    );

    if (httpResponse.candidates.isNotEmpty &&
        httpResponse.candidates[0].content != null &&
        httpResponse.candidates[0].content!['parts'] != null) {
      for (var part in httpResponse.candidates[0].content!['parts']) {
        text += part['text'];
      }
    }

    GeminiResponse response =
        GeminiResponse(text: text, response: httpResponse);
    return response;
  }

  Future<GeminiResponse> generateFromAudio(File audioFile) async {
    String text = '';

    GeminiHttpResponse httpResponse = await apiGenerateAudio(
      audioFile: audioFile,
      apiKey: apiKey,
      config: config,
      safetySettings: safetySettings,
    );

    if (httpResponse.candidates.isNotEmpty &&
        httpResponse.candidates[0].content != null &&
        httpResponse.candidates[0].content!['parts'] != null) {
      for (var part in httpResponse.candidates[0].content!['parts']) {
        text += part['text'];
      }
    }

    GeminiResponse response =
        GeminiResponse(text: text, response: httpResponse);
    return response;
  }
}
