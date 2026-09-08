import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../daily_routine/data/routine_repository.dart';
import '../../daily_routine/domain/models/routine_task.dart';
import '../services/groq_ai_agent_service.dart';
import '../services/local_ai_learner_service.dart';
import '../services/local_schedule_engine.dart';
import '../services/qwen_cloud_model_service.dart';
import '../../profile/data/user_profile_repository.dart';
import 'widgets/offline_model_download_dialog.dart';

/// Modal bottom sheet providing AI-powered routine generation, preset goal chips,
/// schedule preview cards, batch routine application, and offline model management.
class AiPlannerBottomSheet extends StatefulWidget {
  final RoutineRepository routineRepository;
  final LocalScheduleEngine? localScheduleEngine;
  final GroqAiAgentService? groqAiAgentService;
  final QwenCloudModelService? qwenCloudModelService;
  final VoidCallback? onScheduleApplied;

  const AiPlannerBottomSheet({
    super.key,
    required this.routineRepository,
    this.localScheduleEngine,
    this.groqAiAgentService,
    this.qwenCloudModelService,
    this.onScheduleApplied,
  });

  /// Displays the [AiPlannerBottomSheet] modal bottom sheet.
  ///
  /// Returns `true` if an AI schedule was applied, or `null`/`false` if dismissed.
  static Future<bool?> show(
    BuildContext context, {
    required RoutineRepository routineRepository,
    LocalScheduleEngine? localScheduleEngine,
    GroqAiAgentService? groqAiAgentService,
    QwenCloudModelService? qwenCloudModelService,
    VoidCallback? onScheduleApplied,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AiPlannerBottomSheet(
          routineRepository: routineRepository,
          localScheduleEngine: localScheduleEngine,
          groqAiAgentService: groqAiAgentService,
          qwenCloudModelService: qwenCloudModelService,
          onScheduleApplied: onScheduleApplied,
        ),
      ),
    );
  }

  @override
  State<AiPlannerBottomSheet> createState() => _AiPlannerBottomSheetState();
}

class _AiPlannerBottomSheetState extends State<AiPlannerBottomSheet> {
  late final LocalScheduleEngine _localEngine;
  late final GroqAiAgentService _groqService;
  late final QwenCloudModelService _qwenModelService;
  final _promptController = TextEditingController();

  bool _isGenerating = false;
  bool _isApplying = false;
  bool _overwriteExisting = true;
  bool _isUsingLearnedLocalAi = false;
  bool _showOfflineDownloadPrompt = false;
  String? _errorMessage;
  String? _selectedPresetKey;

  List<Map<String, dynamic>> _generatedTasks = [];
  int _selectedDayFilter = 0; // 0 = All Days, 1 = Mon ... 7 = Sun

  static const List<Map<String, String>> _presetTemplates = [
    {
      'key': LocalScheduleEngine.archetypeExamPrep,
      'label': '🎯 Exam Prep Mode',
      'prompt':
          'Create an intensive exam preparation routine with deep study, revision breaks, hydration, and light exercise.',
    },
    {
      'key': LocalScheduleEngine.archetypeHealthyLifestyle,
      'label': '🥗 Healthy & Balanced',
      'prompt':
          'Design a healthy daily routine with exercise, nutritious meals, core work blocks, and night relaxation.',
    },
    {
      'key': LocalScheduleEngine.archetypeDeepWork,
      'label': '⚡ Deep Work & Flow',
      'prompt':
          'Set up a high-productivity deep work schedule featuring high-leverage tasks, focus sprints, and planning.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _localEngine = widget.localScheduleEngine ?? LocalScheduleEngine();
    _groqService = widget.groqAiAgentService ?? GroqAiAgentService();
    _qwenModelService = widget.qwenCloudModelService ?? QwenCloudModelService();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// Fast socket connectivity probe.
  Future<bool> _checkInternetAccess() async {
    try {
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the model download & management dialog.
  Future<void> _openModelManagerDialog() async {
    await OfflineModelDownloadDialog.show(
      context,
      modelService: _qwenModelService,
    );
    final isReady = await _qwenModelService.isModelReady();
    if (mounted && isReady) {
      setState(() {
        _showOfflineDownloadPrompt = false;
        _errorMessage = null;
      });
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'study':
        return const Color(0xFFFF4757);
      case 'health':
        return const Color(0xFF00D2D3);
      case 'work':
        return ThemeController.instance.seedColor;
      case 'personal':
        return const Color(0xFFFFA502);
      default:
        return AppTheme.categoryColor(category);
    }
  }

  List<Map<String, dynamic>> _populateSelectedState(List<Map<String, dynamic>> tasks) {
    return tasks.map((t) => {
      ...t,
      'isSelected': t['isSelected'] as bool? ?? true,
    }).toList();
  }

  void _toggleTaskSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _generatedTasks[index]['isSelected'] as bool? ?? true;
      _generatedTasks[index]['isSelected'] = !current;
    });
  }

  void _toggleSelectAll() {
    HapticFeedback.selectionClick();
    final selectedCount = _generatedTasks.where((t) => t['isSelected'] as bool? ?? true).length;
    final allSelected = selectedCount == _generatedTasks.length;
    final targetState = !allSelected;

    setState(() {
      for (var task in _generatedTasks) {
        task['isSelected'] = targetState;
      }
    });
  }

  void _onPresetSelected(Map<String, String> preset) {
    HapticFeedback.selectionClick();
    final key = preset['key']!;
    final prompt = preset['prompt']!;

    setState(() {
      _selectedPresetKey = key;
      _promptController.text = prompt;
      _errorMessage = null;
      _showOfflineDownloadPrompt = false;
      _generatedTasks = _populateSelectedState(_localEngine.getTemplateSchedule(key));
      _isUsingLearnedLocalAi = false;
    });
  }

  Future<void> _handleGenerate() async {
    final promptText = _promptController.text.trim();

    if (promptText.isEmpty) {
      setState(() => _errorMessage = 'Please describe your ideal routine or select a preset goal.');
      return;
    }

    final focusScope = FocusScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final isOnline = await _checkInternetAccess();
    final isModelReady = await _qwenModelService.isModelReady();

    if (!isOnline && !isModelReady) {
      focusScope.unfocus();
      if (mounted) {
        setState(() {
          _showOfflineDownloadPrompt = true;
          _errorMessage = 'Offline mode requires the on-device AI model.';
        });
      }
      return;
    }

    HapticFeedback.mediumImpact();
    focusScope.unfocus();

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _showOfflineDownloadPrompt = false;
    });

    try {
      if (isOnline) {
        final existingRoutines = _overwriteExisting
            ? <RoutineTask>[]
            : await widget.routineRepository.getRoutines();

        final profileRepo = await UserProfileRepository.create();
        final userProfile = profileRepo.getProfile();
        final userProfileContext = userProfile.toAiContextString();

        final tasks = await _groqService.generateRoutineFromPrompt(
          promptText,
          existingRoutines: existingRoutines,
          localScheduleEngine: _localEngine,
          userProfileContext: userProfileContext,
        );

        final isLocalAi = tasks.any((t) => t['isLearnedLocalAi'] == true);

        // Record & distill pattern into local AI memory every time AI completion succeeds
        LocalAiLearnerService.create().then((l) => l.learnFromAiCompletion(prompt: promptText, tasks: tasks));

        if (mounted) {
          setState(() {
            _generatedTasks = _populateSelectedState(tasks);
            _isGenerating = false;
            _isUsingLearnedLocalAi = isLocalAi;
            _errorMessage = null;
          });
        }
      } else {
        // Offline & Qwen Model is ready
        final learner = await LocalAiLearnerService.create();
        final synthesized = await learner.synthesizeLocallyFromPatterns(promptText);

        final taskMaps = synthesized.isNotEmpty
            ? synthesized.map((t) => {
                'title': t.title,
                'category': t.category,
                'startHour': t.startTime.hour,
                'startMinute': t.startTime.minute,
                'durationMinutes': t.durationMinutes,
                'daysOfWeek': t.daysOfWeek,
                'isSelected': true,
              }).toList()
            : _localEngine.parseCustomPrompt(promptText);

        if (mounted) {
          setState(() {
            _generatedTasks = _populateSelectedState(taskMaps);
            _isGenerating = false;
            _isUsingLearnedLocalAi = true;
            _errorMessage = null;
          });

          messenger.showSnackBar(
            const SnackBar(
              content: Text('Offline: Generated via Qwen-0.5B Local AI'),
            ),
          );
        }
      }
    } catch (e) {
      final isNetworkFailure = e is Exception &&
          (e.toString().contains('SocketException') ||
              e.toString().contains('HandshakeException') ||
              e.toString().contains('Failed host lookup'));

      if (isNetworkFailure) {
        try {
          final learner = await LocalAiLearnerService.create();
          final synthesized = await learner.synthesizeLocallyFromPatterns(promptText);

          final taskMaps = synthesized.map((t) => {
            'title': t.title,
            'category': t.category,
            'startHour': t.startTime.hour,
            'startMinute': t.startTime.minute,
            'durationMinutes': t.durationMinutes,
            'daysOfWeek': t.daysOfWeek,
            'isSelected': true,
          }).toList();

          if (mounted) {
            setState(() {
              _generatedTasks = taskMaps;
              _isGenerating = false;
              _isUsingLearnedLocalAi = true;
              _errorMessage = null;
            });

            messenger.showSnackBar(
              const SnackBar(
                content: Text('Offline: Generated via Local AI'),
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            final fallbackTasks = _localEngine.parseCustomPrompt(promptText);
            setState(() {
              _generatedTasks = _populateSelectedState(fallbackTasks);
              _isGenerating = false;
              _isUsingLearnedLocalAi = true;
              _errorMessage = null;
            });

            messenger.showSnackBar(
              const SnackBar(
                content: Text('Offline: Generated via Local AI'),
              ),
            );
          }
        }
      } else {
        final errText = e.toString().replaceAll('GroqAiAgentException: ', '').replaceAll('Exception: ', '');
        if (mounted) {
          setState(() {
            _isGenerating = false;
            _errorMessage = errText;
          });

          messenger.showSnackBar(
            SnackBar(
              content: Text('Groq API Error: $errText'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleApplySchedule() async {
    final selectedTasks = _generatedTasks
        .where((t) => t['isSelected'] as bool? ?? true)
        .toList();

    if (selectedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one task to apply to your routine schedule.'),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isApplying = true);

    try {
      await widget.routineRepository.applyAiGeneratedRoutine(
        rawAiTasks: selectedTasks,
        overwriteExisting: _overwriteExisting,
      );

      widget.onScheduleApplied?.call();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApplying = false;
          _errorMessage = 'Failed to apply schedule: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply schedule: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final primaryColor = ThemeController.instance.seedColor;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.23),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header handle, title & settings entry point icon button
                _buildHeader(),

                // Main scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preset Mode Selector Chips
                        _buildPresetGoalChips(),
                        const SizedBox(height: 16),

                        // Custom AI Prompt Input
                        _buildPromptInput(),
                        const SizedBox(height: 16),

                        // Offline Download Prompt Banner (if offline and model missing)
                        if (_showOfflineDownloadPrompt) ...[
                          _buildOfflineModelRequiredBanner(),
                          const SizedBox(height: 16),
                        ] else if (_errorMessage != null) ...[
                          // Error indicator if AI fails
                          _buildErrorMessage(),
                          const SizedBox(height: 16),
                        ],

                        // Generate CTA Button
                        _buildGenerateButton(),
                        const SizedBox(height: 20),

                        // Generated Routine Preview List
                        if (_generatedTasks.isNotEmpty) _buildPreviewSection(),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Controls (Cancel / Apply Schedule)
                if (_generatedTasks.isNotEmpty) _buildBottomActionBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final primaryColor = ThemeController.instance.seedColor;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.31),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Routine Planner',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Increase your Aura by 5%',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Settings Entry Point Button for Offline AI Model Management
              Tooltip(
                message: 'Manage Offline AI Engine',
                child: IconButton(
                  onPressed: _openModelManagerDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.offline_bolt_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: theme.dividerColor, height: 1),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPresetGoalChips() {
    final theme = Theme.of(context);
    final primaryColor = ThemeController.instance.seedColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preset Goals',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetTemplates.map((template) {
            final key = template['key']!;
            final label = template['label']!;
            final isSelected = _selectedPresetKey == key;

            return ActionChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.onSurface,
                ),
              ),
              backgroundColor: isSelected
                  ? primaryColor.withValues(alpha: 0.2)
                  : theme.colorScheme.surfaceContainerHighest,
              side: BorderSide(
                color: isSelected
                    ? primaryColor
                    : theme.colorScheme.outline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => _onPresetSelected(template),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPromptInput() {
    final theme = Theme.of(context);
    final primaryColor = ThemeController.instance.seedColor;

    return TextField(
      controller: _promptController,
      maxLines: 3,
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
      onChanged: (val) {
        if (_selectedPresetKey != null) {
          setState(() => _selectedPresetKey = null);
        }
      },
      decoration: InputDecoration(
        labelText: 'Describe Your Ideal Schedule',
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        hintText:
            'e.g., Macho man routine for 2 hours',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
          fontSize: 13,
        ),
        alignLabelWithHint: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildOfflineModelRequiredBanner() {
    final primaryColor = ThemeController.instance.seedColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.wifi_off_rounded, color: Color(0xFFFF6B6B), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Offline mode requires the on-device AI model.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openModelManagerDialog,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text(
                'Download Now (390 MB)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.39)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    final primaryColor = ThemeController.instance.seedColor;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.31),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isGenerating ? null : _handleGenerate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isGenerating
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'AI is Planning Schedule...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Generate Schedule with AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final theme = Theme.of(context);
    final selectedCount = _generatedTasks.where((t) => t['isSelected'] as bool? ?? true).length;
    final totalCount = _generatedTasks.length;
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proposed Schedule ($selectedCount/$totalCount selected)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (totalCount > 0)
                    InkWell(
                      onTap: _toggleSelectAll,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: TextStyle(
                            color: ThemeController.instance.seedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isUsingLearnedLocalAi
                        ? Colors.amber.withValues(alpha: 0.14)
                        : const Color(0xFF00D2D3).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isUsingLearnedLocalAi
                          ? Colors.amber.withValues(alpha: 0.59)
                          : const Color(0xFF00D2D3).withValues(alpha: 0.31),
                    ),
                  ),
                  child: Text(
                    _isUsingLearnedLocalAi
                        ? '⚡ Generated using Local AI Engine'
                        : '✨ Generated using Groq AI Cloud',
                    style: TextStyle(
                      color: _isUsingLearnedLocalAi ? Colors.amber : const Color(0xFF00D2D3),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Day of Week Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDayFilterChip(0, 'All Days'),
              const SizedBox(width: 6),
              _buildDayFilterChip(1, 'Mon'),
              const SizedBox(width: 6),
              _buildDayFilterChip(2, 'Tue'),
              const SizedBox(width: 6),
              _buildDayFilterChip(3, 'Wed'),
              const SizedBox(width: 6),
              _buildDayFilterChip(4, 'Thu'),
              const SizedBox(width: 6),
              _buildDayFilterChip(5, 'Fri'),
              const SizedBox(width: 6),
              _buildDayFilterChip(6, 'Sat'),
              const SizedBox(width: 6),
              _buildDayFilterChip(7, 'Sun'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // List of proposed routines filtered by day
        ..._generatedTasks.asMap().entries.where((entry) {
          if (_selectedDayFilter == 0) return true;
          final daysRaw = entry.value['daysOfWeek'];
          if (daysRaw is! List) return true;
          final days = daysRaw.map((e) => (e as num).toInt()).toList();
          return days.contains(_selectedDayFilter);
        }).map(
          (entry) => _buildPreviewTaskCard(entry.value, entry.key),
        ),
        const SizedBox(height: 16),

        // Replacement / Append toggle switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline,
            ),
          ),
          child: SwitchListTile(
            value: _overwriteExisting,
            contentPadding: EdgeInsets.zero,
            activeTrackColor: ThemeController.instance.seedColor,
            title: Text(
              'Replace current routines',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              _overwriteExisting
                  ? 'Overwrites your current daily routine checklist'
                  : 'Appends new tasks to your current daily routine',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() => _overwriteExisting = val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTaskCard(Map<String, dynamic> task, int index) {
    final theme = Theme.of(context);
    final primaryColor = ThemeController.instance.seedColor;
    final title = task['title'] as String;
    final category = task['category'] as String;
    final startHour = task['startHour'] as int;
    final startMinute = task['startMinute'] as int;
    final durationMinutes = task['durationMinutes'] as int;
    final isSelected = task['isSelected'] as bool? ?? true;

    final categoryColor = _getCategoryColor(category);

    final startTotal = startHour * 60 + startMinute;
    final endTotal = startTotal + durationMinutes;
    final endHour = (endTotal ~/ 60) % 24;
    final endMinute = endTotal % 60;

    final startTimeStr = TimeOfDay(hour: startHour, minute: startMinute).format(context);
    final endTimeStr = TimeOfDay(hour: endHour, minute: endMinute).format(context);
    final timeRangeStr = '$startTimeStr - $endTimeStr';

    return GestureDetector(
      onTap: () => _toggleTaskSelection(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.31),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? categoryColor.withValues(alpha: 0.47)
                : theme.colorScheme.outline.withValues(alpha: 0.16),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Circular Checkbox toggle indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryColor : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),

            // Category colored vertical bar indicator
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? categoryColor : categoryColor.withValues(alpha: 0.31),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Title & Category pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.47),
                      decoration: isSelected ? null : TextDecoration.lineThrough,
                      decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.39),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Category Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? categoryColor.withValues(alpha: 0.16)
                              : categoryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? categoryColor : categoryColor.withValues(alpha: 0.55),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      // Days of week pill
                      if (task['daysOfWeek'] != null && (task['daysOfWeek'] as List).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: isSelected ? 0.12 : 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatDaysOfWeek(task['daysOfWeek']),
                            style: TextStyle(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.55),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      // Time range
                      Text(
                        timeRangeStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.47),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Duration badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDuration(durationMinutes),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.47),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayFilterChip(int dayIndex, String label) {
    final theme = Theme.of(context);
    final primaryColor = ThemeController.instance.seedColor;
    final isSelected = _selectedDayFilter == dayIndex;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _selectedDayFilter = dayIndex);
      },
      selectedColor: primaryColor.withValues(alpha: 0.16),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.47),
      labelStyle: TextStyle(
        color: isSelected
            ? primaryColor
            : theme.colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDaysOfWeek(dynamic daysRaw) {
    if (daysRaw is! List) return 'Daily';
    final days = daysRaw.map((e) => (e as num).toInt()).toList()..sort();
    if (days.isEmpty) return 'Daily';

    if (days.length == 7) return 'Daily';
    if (days.length == 5 && days[0] == 1 && days[4] == 5) return 'Mon-Fri';
    if (days.length == 2 && days[0] == 6 && days[1] == 7) return 'Weekends';

    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    return days.map((d) => dayNames[d] ?? '$d').join(', ');
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return '${hours}h';
    return '${hours}h ${rem}m';
  }

  Widget _buildBottomActionBar() {
    final theme = Theme.of(context);
    final primaryColor = ThemeController.instance.seedColor;
    final selectedCount = _generatedTasks.where((t) => t['isSelected'] as bool? ?? true).length;
    final canApply = !_isApplying && selectedCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isApplying
                  ? null
                  : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.outline),
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: canApply
                    ? LinearGradient(
                        colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
                      )
                    : LinearGradient(
                        colors: [
                          theme.colorScheme.onSurface.withValues(alpha: 0.16),
                          theme.colorScheme.onSurface.withValues(alpha: 0.08),
                        ],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: canApply ? _handleApplySchedule : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                ),
                icon: _isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_isApplying
                    ? 'Applying...'
                    : selectedCount > 0
                        ? 'Apply ($selectedCount)'
                        : 'Apply'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
