import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

const String DETECTION_SYSTEM_PROMPT = """
You are CrisisSync Safety AI — an emergency detection system for hotel venues.
Analyze the sensor data and/or image provided. Determine if an emergency is occurring.

RESPOND ONLY IN VALID JSON. No preamble, no explanation, no markdown code blocks.

Required JSON format:
{
  "incident_detected": true or false,
  "incident_type": "fire" | "security" | "medical" | "none",
  "severity": 1 to 5,
  "affected_floors": [list of integers or empty array],
  "confidence": float between 0.0 and 1.0,
  "immediate_action": "one plain-language sentence",
  "sensor_analysis": "brief reason for this assessment",
  "false_alarm_risk": "low" | "medium" | "high"
}

SEVERITY GUIDE:
1 = Minor / localized — no evacuation needed
2 = Low — precautionary alert to staff only
3 = Moderate — partial floor evacuation recommended
4 = High — full building evacuation recommended
5 = Critical — immediate full evacuation + call emergency services

RULES:
- Only set incident_detected=true if confidence >= 0.75
- If data shows normal hotel activity, return incident_detected=false, type=none
- Never fabricate data. Base assessment only on what is provided.
- false_alarm_risk=high means do NOT auto-trigger evacuation without human confirmation
""";

const String GUEST_INSTRUCTION_PROMPT = """
You are CrisisSync — generating a calm emergency instruction for a hotel guest.
The guest may be panicking. They may not speak the local language.
Your message must be:
- Simple words only (no jargon, no codes)
- Maximum 80 words
- Step-by-step numbered list (max 4 steps)
- End with ONE reassurance sentence
- Written in {LANGUAGE}
Do NOT mention fire investigation, causes, or staff protocols.
Focus only on: what the guest should do RIGHT NOW to get safe.
""";

const String STAFF_INSTRUCTION_PROMPT = """
You are CrisisSync — generating an emergency task list for a hotel staff member.
The staff member is trained and knows the building. Be direct and specific.
Your message must:
- Start with incident type and severity in CAPS
- List exactly 4-6 numbered action items specific to their floor/role
- Include: who to call, where to go, what to confirm
- End with: "Report headcount to command in X minutes"
- Be written in English
- Be under 120 words
""";

const String RESPONDER_INSTRUCTION_PROMPT = """
You are CrisisSync — generating an arriving-unit situation brief for emergency responders.
This is for fire brigade / paramedics arriving at the scene.
Your message must follow this exact structure:
INCIDENT: [type and severity]
LOCATION: [floor and wing]
CURRENT STATUS: [what is happening right now]
UNACCOUNTED: [number of guests not yet confirmed safe]
ACCESS: [which entrance is clear, where to park]
CONTACT: [who to meet at entrance]
Keep each field to one sentence. Total under 100 words. Facts only.
""";

const String GEMINI_API_KEY = String.fromEnvironment('GEMINI_API_KEY');

class GeminiService {
  Future<String> translateMessage(String message, String targetLanguage) async {
    if (targetLanguage.toLowerCase() == 'english') return message;
    if (GEMINI_API_KEY.isEmpty) return message;
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: GEMINI_API_KEY);
      final response = await model.generateContent([
        Content.text("Translate the following emergency message to $targetLanguage. Keep it simple and clear. Return ONLY the translated text, no markdown, no quotes:\n\n$message")
      ]);
      return response.text?.trim() ?? message;
    } catch (e) {
      print("Gemini API Error (Translate): $e");
      return message;
    }
  }

  Future<Map<String, String>> generateAllRoleInstructions({
    required Map<String, dynamic> incident,
    required String guestLanguage,
    required int unaccountedGuests,
    required String venueName,
  }) async {
    if (GEMINI_API_KEY.isEmpty) {
      return {
        "guest": "Emergency. Please evacuate immediately.",
        "staff": "Emergency. Follow standard evacuation protocols.",
        "responder": "Emergency active. More details unavailable.",
      };
    }

    String contextStr = """
INCIDENT CONTEXT:
Type: ${incident['incident_type']}
Severity: ${incident['severity']}/5
Affected Floors: ${(incident['affected_floors'] as List<dynamic>? ?? []).join(', ')}
Immediate Action: ${incident['immediate_action']}
Venue: $venueName
Unaccounted guests: $unaccountedGuests
Assembly Point: Main car park, South entrance
Emergency stairwells: A (East wing) and B (West wing)
""";

    try {
      final guestModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GEMINI_API_KEY,
        systemInstruction: Content.system(GUEST_INSTRUCTION_PROMPT.replaceAllMapped(RegExp(r'\{LANGUAGE\}'), (match) => guestLanguage)),
      );

      final staffModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GEMINI_API_KEY,
        systemInstruction: Content.system(STAFF_INSTRUCTION_PROMPT),
      );

      final responderModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GEMINI_API_KEY,
        systemInstruction: Content.system(RESPONDER_INSTRUCTION_PROMPT),
      );

      final guestResponse = guestModel.generateContent([Content.text(contextStr)]);
      final staffResponse = staffModel.generateContent([Content.text(contextStr)]);
      final responderResponse = responderModel.generateContent([Content.text(contextStr)]);

      final results = await Future.wait([guestResponse, staffResponse, responderResponse]);

      return {
        "guest": results[0].text?.trim() ?? "Emergency. Follow staff instructions immediately.",
        "staff": results[1].text?.trim() ?? "Emergency declared. Evacuate your sector.",
        "responder": results[2].text?.trim() ?? "Emergency reported at $venueName. Proceed with caution.",
      };
    } catch (e) {
      print("Gemini API Error (Role Instructions): $e");
      return {
        "guest": "Emergency. Please evacuate immediately.",
        "staff": "Emergency. Follow standard evacuation protocols.",
        "responder": "Emergency active. More details unavailable.",
      };
    }
  }

  Future<List<Map<String, dynamic>>> getPriorityRescueList(List<Map<dynamic, dynamic>> guestList) async {
    if (GEMINI_API_KEY.isEmpty) return [];

    String priorityPrompt = """
You are a crisis coordinator. Here is the current list of unaccounted or rescue-needed hotel guests.
Rank them by RESCUE PRIORITY from highest to lowest.
Consider: notes (elderly/mobility/infant = higher priority), floor number (higher floors = higher priority if fire).
Return ONLY a JSON array in this format:
[{"roomNumber": "401", "priority": "CRITICAL", "reason": "Elderly guest, Floor 4, mobility aid noted"}]
Priority levels: CRITICAL | HIGH | MEDIUM
Return maximum 10 entries.
${jsonEncode(guestList)}
""";

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GEMINI_API_KEY,
      );

      final response = await model.generateContent([Content.text(priorityPrompt)]);
      String responseText = response.text ?? '[]';
      responseText = responseText.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      
      final list = jsonDecode(responseText) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print("Gemini API Error (Priority Rescue): $e");
      return [];
    }
  }

  Future<String> getDecisionSupportContext(
    Map<String, dynamic> incident,
    int unaccounted,
  ) async {
    if (GEMINI_API_KEY.isEmpty) {
      return "Priority 1: Check affected areas.\nPriority 2: Verify accountability.\nPriority 3: Maintain communication.";
    }

    String prompt = """
You are a crisis coordinator AI.
Based on the incident below, provide 3 brief markdown-formatted priority actions for the command center.
Incident Type: ${incident['incident_type']}
Severity: ${incident['severity']}/5
Affected Floors: ${(incident['affected_floors'] as List<dynamic>? ?? []).join(', ')}
Immediate Action: ${incident['immediate_action']}
Unaccounted Guests: $unaccounted

Keep it under 80 words. Return just the numbered priorities.
""";

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GEMINI_API_KEY,
      );
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "Priority 1: Ensure all guests are accounted for.\nPriority 2: Secure affected areas.\nPriority 3: Await emergency services.";
    } catch (e) {
      print("Gemini API Error (Decision Support): $e");
      return "Priority 1: Check affected areas.\nPriority 2: Verify accountability.\nPriority 3: Maintain communication.";
    }
  }

  Future<String> getEscalationScript(
    Map<String, dynamic> incident,
    int unaccounted,
    String venueName,
  ) async {
    if (GEMINI_API_KEY.isEmpty) {
      return "This is $venueName calling emergency services. We have an incident. Please respond immediately.";
    }

    String prompt = """
You are generating a script for the hotel staff to call 911 / emergency services.
Venue: $venueName
Incident: ${incident['incident_type']}
Severity: ${incident['severity']}/5
Unaccounted Guests: $unaccounted
Affected Floors: ${(incident['affected_floors'] as List<dynamic>? ?? []).join(', ')}

Provide a clear, professional, concise script (under 50 words) to read to the emergency operator.
""";

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GEMINI_API_KEY,
      );
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "Emergency script not available.";
    } catch (e) {
      print("Gemini API Error (Escalation Script): $e");
      return "This is $venueName calling emergency services. We have an incident. Please respond immediately.";
    }
  }

  Future<Map<String, dynamic>> analyze(double temperature, double smokeDensity, double motionEvents) async {
    String sensorText = "Temperature: $temperature, Smoke: $smokeDensity, Motion: $motionEvents";

    print("Received values → Temp: $temperature, Smoke: $smokeDensity, Motion: $motionEvents");

    // Temporary fallback logic
    Map<String, dynamic> fallbackResponse;
    if (temperature > 70 && smokeDensity > 60) {
      fallbackResponse = {
        "incident_detected": true,
        "incident_type": "fire",
        "severity": 5,
        "affected_floors": [1, 2, 3],
        "confidence": 0.95,
        "immediate_action": "Evacuate building immediately. (Fallback)",
      };
    } else if (motionEvents > 40) {
      fallbackResponse = {
        "incident_detected": true,
        "incident_type": "intrusion",
        "severity": 3,
        "affected_floors": [1],
        "confidence": 0.85,
        "immediate_action": "Alert security immediately. (Fallback)",
      };
    } else {
      fallbackResponse = {
        "incident_detected": false,
        "incident_type": "none",
        "severity": 1,
        "affected_floors": [],
        "confidence": 0.0,
        "immediate_action": "No immediate action required. (Fallback)",
      };
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: GEMINI_API_KEY,
        systemInstruction: Content.system(DETECTION_SYSTEM_PROMPT),
      );

      final content = [Content.text(sensorText)];
      final response = await model.generateContent(content);
      
      String responseText = response.text ?? '{}';
      print("----- AFTER API CALL -----");
      print('Response received from Gemini:\n$responseText');
      
      responseText = responseText.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      
      final parsed = jsonDecode(responseText) as Map<String, dynamic>;
      if (parsed.isEmpty) {
        print("Gemini response empty, using fallback");
        return fallbackResponse;
      }
      return parsed;
    } catch (e) {
      print("Gemini API Error (Analyze): $e");
      print("Using fallback logic -> Temp: $temperature, Smoke: $smokeDensity, Motion: $motionEvents");
      return fallbackResponse;
    }
  }
}

