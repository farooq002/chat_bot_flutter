import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chatbot/view/chat_screen/chat_services.dart';

class ChatViewController extends GetxController {
  final messages = <Map<String, dynamic>>[]
      .obs; // Changed to dynamic to hold more data types
  final service = ChatService();
  final textController = TextEditingController();
  final scrollController = ScrollController();
  final isRecording = false.obs;
  final isLoading = false.obs;

  // Recording variables
  var recordingTime = '00:00'.obs;
  var recordingDuration = 0.obs; // in seconds
  Timer? _recordingTimer;
  late String _recordingFilePath;

  // Audio playback
  var currentAudioPath = ''.obs;
  var isPlaying = false.obs;
  var audioDuration = 0.0.obs;
  var audioPosition = 0.0.obs;
  final AudioPlayer player = AudioPlayer();

  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  final FlutterTts _tts = FlutterTts();

  @override
  void onInit() async {
    super.onInit();
    await initRecorder();

    // Setup audio player listeners
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        isPlaying.value = false;
        audioPosition.value = 0;
      }
    });

    player.positionStream.listen((pos) {
      audioPosition.value = pos.inMilliseconds.toDouble();
    });

    player.durationStream.listen((dur) {
      audioDuration.value = dur?.inMilliseconds.toDouble() ?? 0;
    });
  }

  Future<void> initRecorder() async {
    await recorder.openRecorder();

    // Set proper file path for recording
    final directory = await getApplicationDocumentsDirectory();
    _recordingFilePath =
        '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  Future<void> startRecording() async {
    try {
      if (!await recorder.isEncoderSupported(Codec.pcm16WAV)) {
        throw Exception('Audio encoder not supported');
      }
      if (recorder.isRecording) return;

      // Create new file path for each recording
      final directory = await getApplicationDocumentsDirectory();
      _recordingFilePath =
          '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await recorder.startRecorder(
        toFile: _recordingFilePath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      isRecording.value = true;
      recordingDuration.value = 0;

      // Start timer for recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        recordingDuration.value++;
        final minutes = (recordingDuration.value ~/ 60).toString().padLeft(
          2,
          '0',
        );
        final seconds = (recordingDuration.value % 60).toString().padLeft(
          2,
          '0',
        );
        recordingTime.value = '$minutes:$seconds';
      });
    } catch (e) {
      isRecording.value = false;
      Get.snackbar('Recording error', e.toString());
    }
  }

  Future<void> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      if (!recorder.isRecording) return;
      await recorder.stopRecorder();
      isRecording.value = false;
      recordingTime.value = '00:00';
    } catch (e) {
      isRecording.value = false;
      recordingTime.value = '00:00';
    }
  }

  Future<void> handleAudioChat() async {
    if (isRecording.value) {
      await stopRecording();

      // Check if file exists and has minimum duration (1 second)
      final file = File(_recordingFilePath);
      if (!file.existsSync() || recordingDuration.value < 1) {
        return;
      }

      await _sendVoiceMessage(_recordingFilePath, recordingDuration.value);
    } else {
      await startRecording();
    }
  }

  Future<void> _sendVoiceMessage(String audioPath, int duration) async {
    isLoading.value = true;

    try {
      // Add user voice message to chat
      messages.add({
        "type": "voice",
        "role": "user",
        "audioPath": audioPath,
        "duration": duration,
        "timestamp": DateTime.now(),
      });

      scrollToBottom();

      // Send to backend and get transcription
      final botDataMap = await service.sendAudioToPython(audioPath);
      final transcription =
          botDataMap['transcription'] ?? 'Could not transcribe audio';
      final botAudioPath = botDataMap['audioFilePath'] ?? '';

      // Update user message with transcription text
      final lastIndex = messages.length - 1;
      if (lastIndex >= 0) {
        messages[lastIndex]["text"] = transcription;
      }

      // Add bot text response
      messages.add({
        "type": "text",
        "role": "bot",
        "text": transcription,
        "timestamp": DateTime.now(),
      });

      scrollToBottom();

      // Play bot audio response if available
      if (botAudioPath.isNotEmpty && File(botAudioPath).existsSync()) {
        await playAudio(botAudioPath);
      } else {
        // Fallback to TTS
        await _tts.setLanguage("en");
        await _tts.setPitch(1.0);
        await _tts.setSpeechRate(0.4);
        await _tts.speak(transcription);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to process voice message: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendTextMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    // Add user text message
    messages.add({
      "type": "text",
      "role": "user",
      "text": text,
      "timestamp": DateTime.now(),
    });

    textController.clear();
    scrollToBottom();

    // TODO: Send text to backend and get bot response
    // For now, add a dummy bot response
    messages.add({
      "type": "text",
      "role": "bot",
      "text": "Received your message: $text",
      "timestamp": DateTime.now(),
    });

    scrollToBottom();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> playAudio(String path) async {
    if (currentAudioPath.value == path && isPlaying.value) {
      await player.pause();
      isPlaying.value = false;
    } else {
      currentAudioPath.value = path;
      await player.setFilePath(path);
      await player.play();
      isPlaying.value = true;
    }
  }

  @override
  void onClose() async {
    _recordingTimer?.cancel();
    try {
      if (recorder.isRecording) await recorder.stopRecorder();
      await recorder.closeRecorder();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    textController.dispose();
    scrollController.dispose();
    player.dispose();
    super.onClose();
  }
}
