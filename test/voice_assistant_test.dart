import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:career_pilot/services/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel ttsChannel = MethodChannel('flutter_tts');
  const MethodChannel sttChannel = MethodChannel(
    'plugin.csdcorp.com/speech_to_text',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (MethodCall call) async {
          return 1;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sttChannel, (MethodCall call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'has_permission') return true;
          return true;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sttChannel, null);
  });

  group('Voice Assistant Service Tests', () {
    test('VoiceAssistantService initializes with safe default state', () {
      final service = VoiceAssistantService();

      expect(service.isListening, isFalse);
      expect(service.isSpeaking, isFalse);
      expect(service.isPaused, isFalse);

      service.dispose();
    });

    test(
      'VoiceAssistantService handles speech initialization and mock flow',
      () async {
        final service = VoiceAssistantService();

        final isAvailable = await service.initializeSpeech();
        expect(isAvailable, isTrue);

        await service.stopListening();
        await service.stopSpeaking();
        service.dispose();
      },
    );
  });
}
