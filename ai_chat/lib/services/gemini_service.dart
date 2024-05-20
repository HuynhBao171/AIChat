import 'package:ai_chat/models/config/gemini_config.dart';
import 'package:ai_chat/models/config/gemini_safety_settings.dart';
import 'package:ai_chat/models/gemini/gemini.dart';
import 'package:ai_chat/models/gemini/gemini_reponse.dart';

class GeminiService {
  final safety1 = SafetySettings(
      category: SafetyCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
      threshold: SafetyThreshold.BLOCK_ONLY_HIGH);

  final config = GenerationConfig(
      temperature: 0.5,
      maxOutputTokens: 100,
      topP: 0.94,
      topK: 40,
      stopSequences: []);

  // Phương thức generate text
  Future<GeminiResponse> generateFromText(String query) async {
    return await GoogleGemini(safetySettings: [safety1], config: config)
        .generateFromText(query);
  }
}
