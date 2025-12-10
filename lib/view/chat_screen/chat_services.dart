import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ChatService {
  static const String baseUrl = 'http://localhost:8000'; // iOS simulator

  Future<Map<String, dynamic>> sendAudioToPython(
    String audioPath, {
    String language = "ur",
  }) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file does not exist');
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Audio file is empty');
      }

      print('Sending audio to: $baseUrl/audio');
      print('File size: ${bytes.length} bytes');
      print('Language: $language');

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/audio'),
      );

      // Add file
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'audio.wav'),
      );

      // Add language as form field
      request.fields['language'] = language;

      // Send request
      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );

      print('Response status: ${response.statusCode}');

      final responseBody = await response.stream.bytesToString();
      print('Response body: $responseBody');

      if (response.statusCode == 200) {
        // Parse JSON response
        final Map<String, dynamic> jsonResponse =
            json.decode(responseBody) as Map<String, dynamic>;
        return jsonResponse;
      } else {
        throw Exception('Server error: ${response.statusCode}\n$responseBody');
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      throw Exception(
        'Network error. Please check your connection.\nMake sure FastAPI server is running.',
      );
    } on TimeoutException {
      print('Request timeout');
      throw Exception('Request timeout. Server might be unavailable.');
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to send audio: $e');
    }
  }
}
