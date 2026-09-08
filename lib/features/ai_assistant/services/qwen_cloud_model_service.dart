import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for checking, downloading, caching, and managing
/// on-device Qwen GGUF model files.
class QwenCloudModelService {
  /// Default Qwen 2.5 0.5B Instruct GGUF model file name (~390 MB).
  static const String defaultModelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';

  /// Default public Cloud download URL (Hugging Face direct link).
  static const String defaultCloudUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  static const String prefKeyModelDownloaded = 'qwen_model_downloaded';
  static const String prefKeyModelPath = 'qwen_model_path';

  final Dio _dio;
  final SharedPreferences? _prefs;
  final String modelFileName;
  final String cloudUrl;

  QwenCloudModelService({
    Dio? dio,
    SharedPreferences? prefs,
    this.modelFileName = defaultModelFileName,
    this.cloudUrl = defaultCloudUrl,
  })  : _dio = dio ?? Dio(),
        _prefs = prefs;

  /// Returns the path to the `models/` directory in the application's document folder.
  Future<String> getModelsDirectoryPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(docsDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  /// Returns the absolute file path on disk where the `.gguf` model is stored.
  Future<String> getLocalModelPath() async {
    final dirPath = await getModelsDirectoryPath();
    return p.join(dirPath, modelFileName);
  }

  /// Checks if the `.gguf` model file exists locally in `documents/models/` and is not empty.
  Future<bool> isModelReady() async {
    try {
      final path = await getLocalModelPath();
      final file = File(path);
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the GGUF model from the cloud with real-time progress streaming.
  ///
  /// Yields progress values between `0.0` and `1.0`.
  /// Saves to a temporary `.part` file first, then renames/moves to `.gguf` upon complete
  /// download to prevent corrupted or partial file states.
  Stream<double> downloadModel({CancelToken? cancelToken, String? customUrl}) {
    final targetUrl = customUrl ?? cloudUrl;
    final controller = StreamController<double>();

    () async {
      final finalPath = await getLocalModelPath();
      final tempPath = '$finalPath.part';

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      try {
        await _dio.download(
          targetUrl,
          tempPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = (received / total).clamp(0.0, 1.0);
              if (!controller.isClosed) {
                controller.add(progress);
              }
            } else {
              if (!controller.isClosed) {
                controller.add(0.0);
              }
            }
          },
        );

        final downloadedTempFile = File(tempPath);
        if (await downloadedTempFile.exists()) {
          final finalFile = File(finalPath);
          if (await finalFile.exists()) {
            await finalFile.delete();
          }

          await _safeMove(downloadedTempFile, finalPath);

          final prefs = _prefs ?? await SharedPreferences.getInstance();
          await prefs.setBool(prefKeyModelDownloaded, true);
          await prefs.setString(prefKeyModelPath, finalPath);

          if (!controller.isClosed) {
            controller.add(1.0);
            await controller.close();
          }
        } else {
          throw Exception('Downloaded file not found at $tempPath');
        }
      } catch (e, st) {
        final downloadedTempFile = File(tempPath);
        if (await downloadedTempFile.exists()) {
          try {
            await downloadedTempFile.delete();
          } catch (_) {}
        }
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  /// Safely moves a file from [source] to [destinationPath], falling back to copy & delete
  /// if atomic file rename fails across file systems.
  Future<void> _safeMove(File source, String destinationPath) async {
    try {
      await source.rename(destinationPath);
    } catch (_) {
      await source.copy(destinationPath);
      await source.delete();
    }
  }

  /// Deletes the local `.gguf` file (and any `.part` temporary files) to free storage.
  Future<void> deleteModel() async {
    try {
      final path = await getLocalModelPath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      final tempFile = File('$path.part');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(prefKeyModelDownloaded);
      await prefs.remove(prefKeyModelPath);
    } catch (_) {}
  }
}
