import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nooktime/features/ai_assistant/services/qwen_cloud_model_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late QwenCloudModelService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qwen_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    service = QwenCloudModelService(
      prefs: prefs,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('getLocalModelPath returns correct path inside models folder', () async {
    final path = await service.getLocalModelPath();
    expect(path, contains('models'));
    expect(path, endsWith('qwen2.5-0.5b-instruct-q4_k_m.gguf'));
  });

  test('isModelReady returns false when file does not exist', () async {
    final isReady = await service.isModelReady();
    expect(isReady, isFalse);
  });

  test('isModelReady returns true when model file exists and is non-empty', () async {
    final path = await service.getLocalModelPath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('mock model data');

    final isReady = await service.isModelReady();
    expect(isReady, isTrue);
  });

  test('deleteModel removes model file and clears preference state', () async {
    final path = await service.getLocalModelPath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('mock model data');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(QwenCloudModelService.prefKeyModelDownloaded, true);
    await prefs.setString(QwenCloudModelService.prefKeyModelPath, path);

    await service.deleteModel();

    expect(await file.exists(), isFalse);
    expect(prefs.getBool(QwenCloudModelService.prefKeyModelDownloaded), isNull);
    expect(prefs.getString(QwenCloudModelService.prefKeyModelPath), isNull);
  });
}
