import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceAssistantService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isPaused = false;

  bool get isSpeechInitialized => _isSpeechInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;

  VoiceAssistantService() {
    _initTts();
  }

  void _initTts() {
    _tts.setStartHandler(() {
      _isSpeaking = true;
      _isPaused = false;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _isPaused = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _isPaused = false;
      debugPrint('TTS Error: $msg');
    });

    _tts.setPauseHandler(() {
      _isSpeaking = false;
      _isPaused = true;
    });

    _tts.setContinueHandler(() {
      _isSpeaking = true;
      _isPaused = false;
    });

    // Configure friendly natural speech rate & pitch
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
    _tts.setVolume(1.0);
  }

  // =========================================================================
  // SPEECH TO TEXT (CANDIDATE MICROPHONE)
  // =========================================================================

  /// Initializes speech recognition and requests microphone access.
  Future<bool> initializeSpeech() async {
    if (_isSpeechInitialized) return true;

    try {
      _isSpeechInitialized = await _stt.initialize(
        onError: (error) {
          _isListening = false;
          debugPrint('STT Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );
      return _isSpeechInitialized;
    } catch (e) {
      debugPrint('STT initialization error: $e');
      _isSpeechInitialized = false;
      return false;
    }
  }

  /// Starts capturing speech through the microphone and streams recognized text.
  Future<bool> startListening({
    required Function(String words) onResult,
    VoidCallback? onDone,
  }) async {
    // If TTS is currently speaking, stop it so it doesn't feed back into the mic
    await stopSpeaking();

    final isReady = await initializeSpeech();
    if (!isReady) return false;

    _isListening = true;
    try {
      await _stt.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
          if (result.finalResult && onDone != null) {
            onDone();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
      return true;
    } catch (e) {
      _isListening = false;
      debugPrint('Failed to start listening: $e');
      return false;
    }
  }

  /// Stops speech capture cleanly.
  Future<void> stopListening() async {
    if (_isListening) {
      _isListening = false;
      try {
        await _stt.stop();
      } catch (_) {}
    }
  }

  // =========================================================================
  // TEXT TO SPEECH (AI INTERVIEWER VOICE)
  // =========================================================================

  /// Reads a question or feedback aloud.
  Future<void> speak(String text, {VoidCallback? onComplete}) async {
    // If mic is active, stop it before speaking
    await stopListening();

    if (text.trim().isEmpty) return;

    if (onComplete != null) {
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _isPaused = false;
        onComplete();
      });
    }

    try {
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('TTS speak error: $e');
    }
  }

  /// Stops playback immediately.
  Future<void> stopSpeaking() async {
    if (_isSpeaking || _isPaused) {
      _isSpeaking = false;
      _isPaused = false;
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  /// Pauses playback.
  Future<void> pauseSpeaking() async {
    if (_isSpeaking) {
      try {
        await _tts.pause();
      } catch (_) {}
    }
  }

  /// Resumes playback.
  Future<void> resumeSpeaking() async {
    if (_isPaused) {
      try {
        // flutter_tts handles resume or re-speaking
        _isSpeaking = true;
        _isPaused = false;
      } catch (_) {}
    }
  }

  /// Cleans up audio resources and cancels any active captures.
  void dispose() {
    stopListening();
    stopSpeaking();
  }
}
