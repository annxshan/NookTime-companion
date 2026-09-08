import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nooktime/features/ai_assistant/presentation/widgets/offline_model_download_dialog.dart';
import 'package:nooktime/features/ai_assistant/services/qwen_cloud_model_service.dart';

class MockQwenCloudModelService extends Mock implements QwenCloudModelService {
  @override
  Future<bool> isModelReady() async {
    return super.noSuchMethod(
      Invocation.method(#isModelReady, []),
      returnValue: Future.value(false),
      returnValueForMissingStub: Future.value(false),
    ) as Future<bool>;
  }

  @override
  Future<void> deleteModel() async {
    return super.noSuchMethod(
      Invocation.method(#deleteModel, []),
      returnValue: Future<void>.value(),
      returnValueForMissingStub: Future<void>.value(),
    ) as Future<void>;
  }

  @override
  Stream<double> downloadModel({dynamic cancelToken, String? customUrl}) {
    return super.noSuchMethod(
      Invocation.method(#downloadModel, [], {#cancelToken: cancelToken, #customUrl: customUrl}),
      returnValue: const Stream<double>.empty(),
      returnValueForMissingStub: const Stream<double>.empty(),
    ) as Stream<double>;
  }
}

void main() {
  testWidgets('OfflineModelDownloadDialog renders Not Downloaded state correctly', (tester) async {
    final mockService = MockQwenCloudModelService();
    when(mockService.isModelReady()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineModelDownloadDialog(modelService: mockService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Download Offline AI Engine'), findsOneWidget);
    expect(find.text('One-time download: ~390 MB'), findsOneWidget);
    expect(find.text('Download Model'), findsOneWidget);
  });

  testWidgets('OfflineModelDownloadDialog renders Downloaded & Ready state correctly', (tester) async {
    final mockService = MockQwenCloudModelService();
    when(mockService.isModelReady()).thenAnswer((_) async => true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineModelDownloadDialog(modelService: mockService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline AI Engine Ready'), findsOneWidget);
    expect(find.text('Delete Model to Free Storage'), findsOneWidget);
  });
}
