import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:ai_chat/config/constants.dart';
import 'package:ai_chat/models/config/gemini_config.dart';
import 'package:ai_chat/models/config/gemini_safety_settings.dart';
import 'package:ai_chat/models/gemini/gemini_reponse.dart';
import 'package:http/http.dart' as http;

/// Convert safetySettings List int a json
List<Map<String, dynamic>> _convertSafetySettings(
    List<SafetySettings> safetySettings) {
  List<Map<String, dynamic>> list = [];
  for (var element in safetySettings) {
    list.add(element.toJson());
  }
  return list;
}

/// Generate Text from a query with Gemini Api and http
/// requires a query, an apiKey,
Future<GeminiHttpResponse> apiGenerateText(
    {required String query,
    required String apiKey,
    required GenerationConfig? config,
    required List<SafetySettings>? safetySettings,
    String model = 'gemini-1.5-pro'}) async {
  var url = Uri.https(
      Constants.endpoit,
      'v1/projects/plasma-card-407515/locations/{REGION}/publishers/google/models/$model',
      {'key': apiKey});

  log("--- Generating ---");

  var response = await http.post(url,
      body: json.encode({
        "contents": [
          {
            "parts": [
              {"text": query}
            ]
          }
        ],
        "safetySettings": _convertSafetySettings(safetySettings ?? []),
        "generationConfig": config?.toJson()
      }));

  log("--- Http Status ${response.statusCode} ---");

  if (response.statusCode == 200) {
    return GeminiHttpResponse.fromJson(json.decode(response.body));
  } else {
    throw Exception(
        'Failed to Generate Text: ${response.statusCode}\n${response.body}');
  }
}

/// Convert a File into a base64 String
String _convertIntoBase64(File file) {
  log("--- ${file.path} ---");
  List<int> imageBytes = file.readAsBytesSync();
  String base64File = base64Encode(imageBytes);
  return base64File;
}

Future<GeminiHttpResponse> apiGenerateAudio(
    {required File audioFile,
    required String apiKey,
    required GenerationConfig? config,
    required List<SafetySettings>? safetySettings,
    String model = 'gemini-1.5-pro'}) async {
  var url = Uri.https(
      Constants.endpoit,
      'v1/projects/plasma-card-407515/locations/asia-southeast1/publishers/google/models/$model',
      {'key': apiKey});

  log("--- Generating from audio ---");

  // Convert audio file to base64
  String base64Audio = _convertIntoBase64(audioFile);

  var response = await http.post(url,
      body: json.encode({
        "contents": [
          {
            "parts": [
              {
                "audio": {
                  "audioEncoding": "LINEAR16",
                  "audioContent": base64Audio
                }
              }
            ]
          }
        ],
        "safetySettings": _convertSafetySettings(safetySettings ?? []),
        "generationConfig": config?.toJson()
      }));

  log("--- Http Status ${response.statusCode} ---");

  if (response.statusCode == 200) {
    return GeminiHttpResponse.fromJson(json.decode(response.body));
  } else {
    throw Exception(
        'Failed to Generate Text: ${response.statusCode}\n${response.body}');
  }
}
