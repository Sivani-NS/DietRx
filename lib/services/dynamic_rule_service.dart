import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/health_rules.dart';

class DynamicRuleService {
  static const String _apiKey = 'AIzaSyAVdEgfRojGWvQvNafmXHlfU3J8jURlT4U'; 

  static Future<HealthRule?> generateRuleForCondition(String conditionName, {bool isAllergy = false}) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      String context = isAllergy 
          ? "The user has a severe allergy to: $conditionName. Focus heavily on all possible hidden ingredient names, derivatives, and cross-reactants."
          : "The user is diagnosed with: $conditionName. Focus on both forbidden ingredients and strict macronutrient/micronutrient limits.";

      final prompt = '''
      You are an expert clinical nutritionist and allergist.
      $context
      
      Create a strict dietary rulebook for this condition.
      
      Reply ONLY with a valid JSON object in this EXACT format. Do not use markdown blocks (like ```json).
      {
        "forbiddenKeywords": [
          // List of ingredient strings to strictly avoid (lowercase).
          // If allergy, list all derivatives (e.g., for dairy: whey, casein, butter).
        ],
        "nutrientLimits": {
          // Map of strict maximum limits in grams per 100g. 
          // ONLY use these exact keys if applicable: 'sugar_100g', 'salt_100g', 'fat_100g', 'sat_fat_100g', 'carbs_100g', 'sodium_100g', 'cholesterol_100g', 'trans_fat_100g' etc.
          // If no specific numerical limit is required for a nutrient, omit it.
          // For allergies, this should usually be empty {}.
        }
      }
      ''';

      print("Asking Gemini to generate rules for: $conditionName...");
      final response = await model.generateContent([Content.text(prompt)]);
      
      String responseText = response.text ?? '{}';
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      final Map<String, dynamic> jsonResponse = jsonDecode(responseText);
      
      // Parse the JSON into our Dart HealthRule format
      List<String> keywords = [];
      if (jsonResponse['forbiddenKeywords'] != null) {
        keywords = List<String>.from(jsonResponse['forbiddenKeywords']);
      }

      Map<String, double> limits = {};
      if (jsonResponse['nutrientLimits'] != null) {
        Map<String, dynamic> limitsJson = jsonResponse['nutrientLimits'];
        limitsJson.forEach((key, value) {
          limits[key] = (value as num).toDouble();
        });
      }

      return HealthRule(
        forbiddenKeywords: keywords,
        nutrientLimits: limits,
      );

    } catch (e) {
      print("Gemini API Error while generating rule: $e");
      return null;
    }
  }
}