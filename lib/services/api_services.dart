// lib/services/api_services.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiServices {
  // Point to your Flask server
  static const String baseUrl = "http://10.0.2.2:5000";

  /// Send user input in the "messages" array format required by the new /chat endpoint.
  static Future<String> sendChatPrompt(String userPrompt) async {
    final url = Uri.parse("$baseUrl/chat");

    // Build the body as { "messages": [...], "web_access": false }
    final requestBody = {

      "messages": [
        {"role": "system", "content": "Respond as a Professional Farm consultant by providing a concise plant information (scientific name, estimated harvest selling price locally, and normal harvest period), a brief summary of the possible diagnosis of the complaint, recommendations of specific countermeasures to the complaint/problem at hand. Explain in simple terms. The answer should be in Bahasa Indonesia. Separate each section of plant description, diagnosis, and recommendation using a clear-cut line such as =========."},
        {"role": "user","content": userPrompt,}
      ],

      "web_access": false

    };

    // Make the POST request
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // The server returns {"answer": "..."}
      return data["answer"] ?? "No answer returned";
    } else {
      throw Exception(
          "Failed with status ${response.statusCode}: ${response.reasonPhrase}");
    }
  }

  /// Upload an audio file for Whisper transcription
  static Future<String> transcribeAudio(File audioFile) async {
    final url = Uri.parse("$baseUrl/transcribe");

    final request = http.MultipartRequest("POST", url)
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["transcription"] ?? "No transcription found";
    } else {
      throw Exception(
        "Failed to transcribe audio: ${response.statusCode} ${response.reasonPhrase}"
      );
    }
  }
}
