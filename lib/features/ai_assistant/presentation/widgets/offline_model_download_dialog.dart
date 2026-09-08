import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../services/qwen_cloud_model_service.dart';

/// Interactive dialog for downloading, monitoring progress, and managing the local
/// on-device Qwen 2.5 0.5B GGUF model file.
class OfflineModelDownloadDialog extends StatefulWidget {
  final QwenCloudModelService? modelService;
  final VoidCallback? onModelStatusChanged;

  const OfflineModelDownloadDialog({
    super.key,
    this.modelService,
    this.onModelStatusChanged,
  });

  /// Displays the Offline Model Download Dialog modally.
  static Future<void> show(
    BuildContext context, {
    QwenCloudModelService? modelService,
    VoidCallback? onModelStatusChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => OfflineModelDownloadDialog(
        modelService: modelService,
        onModelStatusChanged: onModelStatusChanged,
      ),
    );
  }

  @override
  State<OfflineModelDownloadDialog> createState() =>
      _OfflineModelDownloadDialogState();
}

class _OfflineModelDownloadDialogState
    extends State<OfflineModelDownloadDialog> {
  late final QwenCloudModelService _modelService;
  bool _isLoadingStatus = true;
  bool _isReady = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;

  CancelToken? _cancelToken;
  StreamSubscription<double>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _modelService = widget.modelService ?? QwenCloudModelService();
    _checkStatus();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoadingStatus = true);
    final ready = await _modelService.isModelReady();
    if (mounted) {
      setState(() {
        _isReady = ready;
        _isLoadingStatus = false;
      });
    }
  }

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
    });

    _cancelToken = CancelToken();
    _downloadSubscription?.cancel();

    _downloadSubscription = _modelService
        .downloadModel(cancelToken: _cancelToken)
        .listen(
      (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
            if (progress >= 1.0) {
              _isDownloading = false;
              _isReady = true;
              widget.onModelStatusChanged?.call();
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            if (error is DioException && CancelToken.isCancel(error)) {
              _errorMessage = 'Download canceled.';
            } else {
              _errorMessage = 'Download failed: ${error.toString()}';
            }
          });
        }
      },
      onDone: () {
        if (mounted && _isDownloading) {
          setState(() {
            _isDownloading = false;
          });
        }
      },
    );
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User canceled download');
    _downloadSubscription?.cancel();
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _progress = 0.0;
      });
    }
  }

  Future<void> _deleteModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Model File?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will remove the 390 MB Qwen AI model from your device storage. You will need to download it again to use offline generation.',
          style: TextStyle(color: Color(0xFF8A9BBF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A9BBF))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _modelService.deleteModel();
      await _checkStatus();
      widget.onModelStatusChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final accentColor = ThemeController.instance.seedColor;
        const cardBg = Color(0xFF1A2230);
        const borderColor = Color(0xFF2A364F);

        return Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row: Icon, Title & Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: accentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Download Offline AI Engine',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enable complete offline routine generation powered by Qwen2.5-0.5B (390 MB).',
                            style: TextStyle(
                              color: Color(0xFF8A9BBF),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF8A9BBF)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main State Container
                if (_isLoadingStatus)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: accentColor),
                    ),
                  )
                else if (_isReady)
                  // State 3: Downloaded & Ready
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00B894).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF00B894),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Offline AI Engine Ready',
                            style: TextStyle(
                              color: Color(0xFF00B894),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isDownloading)
                  // State 2: Downloading
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Downloading Qwen Model...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 8,
                          backgroundColor: borderColor,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 390.0).toStringAsFixed(1)} MB / 390 MB',
                        style: const TextStyle(
                          color: Color(0xFF8A9BBF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                else
                  // State 1: Not Downloaded
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F141C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.sd_card_rounded,
                          color: Color(0xFF8A9BBF),
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'One-time download: ~390 MB',
                            style: TextStyle(
                              color: Color(0xFFE8EDF5),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                if (!_isLoadingStatus)
                  if (_isReady)
                    OutlinedButton.icon(
                      onPressed: _deleteModel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6B6B),
                        side: const BorderSide(color: Color(0xFFFF6B6B)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text(
                        'Delete Model to Free Storage',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else if (_isDownloading)
                    OutlinedButton.icon(
                      onPressed: _cancelDownload,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8A9BBF),
                        side: const BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      label: const Text(
                        'Cancel Download',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _startDownload,
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Download Model',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
