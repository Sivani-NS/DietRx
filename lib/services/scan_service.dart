import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';
import '../utils/health_rules.dart';
import '../models/scan_result.dart';

class ScanService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<ScanResult?> processBarcode(String barcode) async {
    // A. Fetch Product from SQLite
    final product = await _dbHelper.getProduct(barcode);
    if (product == null) return null;

    // B. Parse Data
    String name = product['name'] ?? "Unknown Product";
    String ingredients = (product['ingredients'] ?? "").toLowerCase();
    String? imageUrl = product['image_url'];
    String? nutriscore = product['nutriscore'];
    int? novaGroup = product['nova_group'] as int?;
    String? categories = product['categories'];
    String? labels = product['labels'];

    // Map nutrients
    Map<String, double?> nutrients = {
      'sugar_100g': product['sugars_100g'] as double?,
      'salt_100g': product['salt_100g'] as double?,
      'fat_100g': product['fat_100g'] as double?,
      'sat_fat_100g': product['saturated_fat_100g'] as double?,
      'calories_100g': product['calories_100g'] as double?,
      'carbs_100g': product['carbohydrates_100g'] as double?,
      'sodium_100g': product['sodium_100g'] as double?,
      'cholesterol_100g': product['cholesterol_100g'] as double?,
      'trans_fat_100g': product['trans_fat_100g'] as double?,
    };

    List<String> warnings = [];
    List<String> unknown = [];

    bool isMissingData =
        (nutrients['sugar_100g'] == null &&
        nutrients['salt_100g'] == null &&
        nutrients['fat_100g'] == null &&
        nutrients['sat_fat_100g'] == null);

    // --- C. FETCH USER PROFILE ---
    List<String> userConditions = [];
    List<String> userAllergies = [];

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var doc = await FirebaseFirestore.instance
            .collection('Health_Profiles')
            .doc(user.uid)
            .get();
        Map<String, dynamic>? data;

        if (doc.exists) {
          data = doc.data();
        } else {
          final query = await FirebaseFirestore.instance
              .collection('Health_Profiles')
              .where('user_id', isEqualTo: user.uid)
              .get();

          if (query.docs.isNotEmpty) {
            data = query.docs.first.data();
          }
        }

        if (data != null) {
          if (data['conditions'] != null) {
            userConditions = List<String>.from(data['conditions']);
          } else if (data['diseases'] != null) {
            userConditions = List<String>.from(data['diseases']);
          }

          if (data['allergies'] != null) {
            userAllergies = List<String>.from(data['allergies']);
          }
        }
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }

    // --- FETCH DYNAMIC RULES FROM FIRESTORE ---
    Map<String, HealthRule> combinedRules = Map.of(diseaseRules);
    Set<String> allUserConditions = {...userConditions, ...userAllergies};

    for (String condition in allUserConditions) {
      String docId = condition.trim().toLowerCase();
      
      bool existsLocally = combinedRules.keys.any((k) => k.toLowerCase() == docId);
      
      if (!existsLocally) {
        try {
          DocumentSnapshot ruleDoc = await FirebaseFirestore.instance.collection('Dynamic_Rules').doc(docId).get();
          
          if (ruleDoc.exists) {
            var data = ruleDoc.data() as Map<String, dynamic>;
            List<String> keywords = List<String>.from(data['forbiddenKeywords'] ?? []);
            Map<String, double> limits = {};
            
            if (data['nutrientLimits'] != null) {
              (data['nutrientLimits'] as Map<String, dynamic>).forEach((key, value) {
                limits[key] = (value as num).toDouble();
              });
            }
            
            combinedRules[condition] = HealthRule(
              forbiddenKeywords: keywords,
              nutrientLimits: limits,
            );
          } else {
            unknown.add(condition);
          }
        } catch (e) {
          print("Error fetching dynamic rule for $condition: $e");
          unknown.add(condition);
        }
      }
    }

    // D. ANALYZE HEALTH RULES
    for (var condition in userConditions) {
      // Use combinedRules instead of diseaseRules
      if (combinedRules.containsKey(condition)) {
        final rule = combinedRules[condition]!;

        // 1. Check Nutrient Limits
        rule.nutrientLimits.forEach((nutrientKey, limit) {
          double? val = nutrients[nutrientKey];

          if (val != null && val > limit) {
            warnings.add(
              "$condition: High $nutrientKey (${val}g > ${limit}g)",
            );
          }
        });

        // 2. Check Ingredients (Text)
        for (var forbidden in rule.forbiddenKeywords) {
          if (ingredients.contains(forbidden.toLowerCase())) {
            warnings.add("$condition: Contains '$forbidden'");
            break;
          }
        }
      }
    }

    // 2. Check Allergies
    String allergenCol = (product['allergens'] ?? "").toLowerCase();
    for (var allergy in userAllergies) {
      if (allergenCol.contains(allergy.toLowerCase())) {
        warnings.add("ALLERGY: Contains $allergy");
        continue;
      }
      if (ingredients.contains(allergy.toLowerCase())) {
        warnings.add("ALLERGY: Contains $allergy (Found in ingredients)");
        continue;
      }
      // Use combinedRules instead of diseaseRules
      if (combinedRules.containsKey(allergy)) {
        final rule = combinedRules[allergy]!;
        for (var forbidden in rule.forbiddenKeywords) {
          if (ingredients.contains(forbidden.toLowerCase())) {
            warnings.add("ALLERGY: Contains $forbidden");
            break;
          }
        }
      }
    }

    // 3. Nova Warning
    if (novaGroup == 4) {
      warnings.add("Ultra-Processed Food (Nova 4)");
    }

    // --- E. FIND ALTERNATIVES ---
    List<Map<String, dynamic>> safeAlternatives = [];

    // Only look for alternatives if Unsafe or Totally Missing Data
    if ((warnings.isNotEmpty || isMissingData) &&
        categories != null &&
        categories.isNotEmpty) {
      final candidates = await _dbHelper.getAlternatives(categories);

      for (var item in candidates) {
        if (item['barcode'] == barcode) continue;

        String? safetyReason = _getSafetyReason(
          item,
          userConditions,
          userAllergies,
          combinedRules, 
        );

        if (safetyReason != null) {
          Map<String, dynamic> safeItem = Map<String, dynamic>.from(item);
          safeItem['match_reason'] = safetyReason;
          safeAlternatives.add(safeItem);
        }

        if (safeAlternatives.length >= 5) break;
      }
    }

    return ScanResult(
      productName: name,
      // Safe if: No Warnings AND Data isn't completely missing
      isSafe: warnings.isEmpty && !isMissingData,
      isMissingData: isMissingData,
      warnings: warnings,
      unknownConditions: unknown,
      alternatives: safeAlternatives,
      imageUrl: imageUrl,
      nutriscore: nutriscore,
      novaGroup: novaGroup,
      categories: categories,
      labels: labels,
      sugar: nutrients['sugar_100g'],
      salt: nutrients['salt_100g'],
      fat: nutrients['fat_100g'],
      calories: nutrients['calories_100g'],
    );
  }

  // Updated helper to accept combinedRules map
  String? _getSafetyReason(
    Map<String, dynamic> item,
    List<String> conditions,
    List<String> allergies,
    Map<String, HealthRule> rules,
  ) {
    String ingredients = (item['ingredients'] ?? "").toLowerCase();
    String allergenCol = (item['allergens'] ?? "").toLowerCase();

    Map<String, double?> nutrients = {
      'sugar_100g': item['sugars_100g'] as double?,
      'salt_100g': item['salt_100g'] as double?,
      'fat_100g': item['fat_100g'] as double?,
      'sat_fat_100g': item['saturated_fat_100g'] as double?,
      'carbs_100g': item['carbohydrates_100g'] as double?,
      'sodium_100g': item['sodium_100g'] as double?,
      'cholesterol_100g': item['cholesterol_100g'] as double?,
      'trans_fat_100g': item['trans_fat_100g'] as double?,
    };

    List<String> goodPoints = [];

    for (var condition in conditions) {
      if (rules.containsKey(condition)) {
        final rule = rules[condition]!;

        bool failed = false;
        rule.nutrientLimits.forEach((key, limit) {
          double? val = nutrients[key];
          if (val == null)
            failed = true;
          else if (val > limit)
            failed = true;
          else
            goodPoints.add("Low ${key.replaceAll('_100g', '')} (${val}g)");
        });

        if (failed) return null;

        for (var forbidden in rule.forbiddenKeywords) {
          if (ingredients.contains(forbidden.toLowerCase())) return null;
        }
      }
    }

    for (var allergy in allergies) {
      if (allergenCol.contains(allergy.toLowerCase())) return null;
      if (ingredients.contains(allergy.toLowerCase())) return null;
      
      if (rules.containsKey(allergy)) {
        for (var forbidden in rules[allergy]!.forbiddenKeywords) {
          if (ingredients.contains(forbidden.toLowerCase())) return null;
        }
      }
      
      goodPoints.add("No $allergy");
    }

    if (goodPoints.isEmpty) return "Safe for general consumption.";

    return goodPoints.toSet().join(" • ");
  }
}