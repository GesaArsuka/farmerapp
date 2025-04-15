import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiServices {
  static const String baseUrl = "https://nh73cp8f-5000.asse.devtunnels.ms/";

  /// NEW: Send text + optional image via multipart/form-data to /chat_with_image.
  static Future<Map<String, dynamic>> sendChatPromptMultipart({
    required String plantName,
    required String complaint,
    File? imageFile,
    String? conversationId,
  }) async {
    final url = Uri.parse("$baseUrl/chat");

    // Build the multipart request.
    final request = http.MultipartRequest("POST", url)
      ..fields["plantName"] = plantName
      ..fields["complaint"] = complaint;

    // If continuing an existing conversation, pass the ID.
    if (conversationId != null) {
      request.fields["conversation_id"] = conversationId;
    }

    // Attach the image if provided.
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath("file", imageFile.path),
      );
    }

    // Send the request and parse the response.
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        "answer": data["answer"] ?? "No answer returned",
        "conversation_id": data["conversation_id"],
      };
    } else {
      throw Exception(
        "Failed with status ${response.statusCode}: ${response.reasonPhrase}"
      );
    }
  }

  /// Existing methods below (unchanged)...

  static Future<List<dynamic>> getArchivedConversations() async {
    final url = Uri.parse("$baseUrl/conversations?archived=true");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["conversations"];
    } else {
      throw Exception("Failed to fetch archived conversations: ${response.statusCode}");
    }
  }

  static Future<List<dynamic>> getConversationHistory(String conversationId) async {
    final url = Uri.parse("$baseUrl/conversation/$conversationId");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["messages"];
    } else {
      throw Exception("Failed to fetch conversation history: ${response.statusCode}");
    }
  }

  static Future<Map<String, dynamic>> sendChatPromptWithConversation(
    List<Map<String, String>> messages, {String? conversationId}) async {
  // Use the followup endpoint if conversationId exists, otherwise use /chat for new conversations.
  final String endpoint = (conversationId == null) ? "chat" : "chat_followup";
  final url = Uri.parse("$baseUrl/$endpoint");

  final Map<String, dynamic> requestBody = {"messages": messages};

  if (conversationId != null) {
    requestBody["conversation_id"] = conversationId;
  }

  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode(requestBody),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return {
      "answer": data["answer"] ?? "No answer returned",
      "conversation_id": data["conversation_id"]
    };
  } else {
    throw Exception(
      "Failed with status ${response.statusCode}: ${response.reasonPhrase}"
    );
  }
}



  static Future<Map<String, dynamic>> sendChatPrompt(String userPrompt) async {
    List<Map<String, String>> messages = [
      {"role": "user", "content": userPrompt}
    ];
    return await sendChatPromptWithConversation(messages);
  }

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

  static Future<String> deleteConversation(String conversationId) async {
    final url = Uri.parse("$baseUrl/conversation/$conversationId");
    final response = await http.delete(url, headers: {"Content-Type": "application/json"});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["status"] ?? "Deleted";
    } else {
      throw Exception("Failed to delete conversation: ${response.statusCode}");
    }
  }

  static Future<String> archiveConversation(String conversationId) async {
    final url = Uri.parse("$baseUrl/archive");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"conversation_id": conversationId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["status"] ?? "Archived";
    } else {
      throw Exception(
        "Failed to archive conversation: ${response.statusCode}"
      );
    }
  }
}
