import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/health_rules.dart';
import 'dynamic_rule_service.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addCustomCondition(String conditionName, {required bool isAllergy}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    String formattedName = conditionName.trim();
    if (formattedName.isEmpty) return;
    
    String docId = formattedName.toLowerCase();

    try {
      // --- STEP 1: Check Local Rules ---
      // (Case-insensitive check against your health_rules.dart)
      bool existsLocally = diseaseRules.keys.any((key) => key.toLowerCase() == docId);
      
      if (!existsLocally) {
        // --- STEP 2: Check Firebase "Dynamic_Rules" ---
        final ruleDoc = await _firestore.collection('Dynamic_Rules').doc(docId).get();
        
        if (!ruleDoc.exists) {
          // --- STEP 3: Not in Firebase either! Call API ---
          print("🔍 $formattedName is completely unknown. Asking Gemini...");
          
          HealthRule? newRule = await DynamicRuleService.generateRuleForCondition(
            formattedName, 
            isAllergy: isAllergy,
          );

          if (newRule == null) {
            throw Exception("Failed to generate health rules. Please try again.");
          }

          // --- STEP 4: Save Gemini's answer to Firebase for everyone ---
          print("Saving new rules for $formattedName to Firestore...");
          await _firestore.collection('Dynamic_Rules').doc(docId).set({
            'original_name': formattedName,
            'type': isAllergy ? 'allergy' : 'disease',
            'forbiddenKeywords': newRule.forbiddenKeywords,
            'nutrientLimits': newRule.nutrientLimits,
            'created_at': FieldValue.serverTimestamp(),
          });
        } else {
          print("$formattedName rules already exist in Firebase from another user!");
        }
      }

      // --- STEP 5: Add to the User's Personal Profile ---
      final userRef = _firestore.collection('Health_Profiles').doc(user.uid);
      
      if (isAllergy) {
        await userRef.set({
          'allergies': FieldValue.arrayUnion([formattedName])
        }, SetOptions(merge: true));
      } else {
        await userRef.set({
          'conditions': FieldValue.arrayUnion([formattedName])
        }, SetOptions(merge: true));
      }

      print("Successfully added $formattedName to profile!");

    } catch (e) {
      print("Error adding custom condition: $e");
      rethrow;
    }
  }
}