import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ChatService {
  static const String baseUrl = 'http://localhost:8000';


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
      print('File size: ${bytes.length} bytes');
      print('Language: $language');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$baseUrl/audio',
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'audio.wav'),
      );
      request.fields['language'] = language;
      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final responseBody = await response.stream.bytesToString();
      print('Response body: $responseBody');

      if (response.statusCode == 200) {
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
      throw Exception('Request timeout. Server might be unavailable.');
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to send audio: $e');
    }
  }
}
