import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_controller.dart';
import '../../daily_routine/data/routine_repository.dart';
import '../../daily_routine/domain/models/routine_task.dart';
import '../../daily_routine/domain/models/task_type.dart';
import '../services/groq_ai_agent_service.dart';
import '../services/local_ai_learner_service.dart';
import '../services/local_schedule_engine.dart';
import '../services/qwen_cloud_model_service.dart';
import '../../profile/data/user_profile_repository.dart';
import 'widgets/offline_model_download_dialog.dart';
import 'widgets/staged_task_card.dart';

/// Full-screen interactive AI Routine Studio for multi-turn conversational routine creation,
/// day-by-day visual editing, inline task adjustments, and weekly schedule commitment.
///
/// Features dynamic network status checking, offline Qwen2.5-0.5B model status monitoring,
/// tactical HUD status beacon, and automatic execution fallback.
class AiRoutineStudioScreen extends StatefulWidget {
  final RoutineRepository routineRepository;
  final LocalScheduleEngine? localScheduleEngine;
  final GroqAiAgentService? groqAiAgentService;
  final QwenCloudModelService? qwenCloudModelService;

  const AiRoutineStudioScreen({
    super.key,
    required this.routineRepository,
    this.localScheduleEngine,
    this.groqAiAgentService,
    this.qwenCloudModelService,
  });

  /// Static helper to open [AiRoutineStudioScreen] as a full-screen route.
  static Future<bool?> open(
    BuildContext context, {
    required RoutineRepository routineRepository,
    LocalScheduleEngine? localScheduleEngine,
    GroqAiAgentService? groqAiAgentService,
    QwenCloudModelService? qwenCloudModelService,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AiRoutineStudioScreen(
          routineRepository: routineRepository,
          localScheduleEngine: localScheduleEngine,
          groqAiAgentService: groqAiAgentService,
          qwenCloudModelService: qwenCloudModelService,
        ),
      ),
    );
  }

  @override
  State<AiRoutineStudioScreen> createState() => _AiRoutineStudioScreenState();
}

class _AiRoutineStudioScreenState extends State<AiRoutineStudioScreen> {
  late final LocalScheduleEngine _localEngine;
  late final GroqAiAgentService _groqService;
  late final QwenCloudModelService _qwenModelService;

  final _chatInputController = TextEditingController();
  final ScrollController _previewScrollController = ScrollController();

  int _selectedDayIndex = 1; // 1 = Monday ... 7 = Sunday
  bool _isProcessing = false;
  bool _isApplying = false;
  bool _isOnline = true;
  bool _isQwenReady = false;
  String? _errorMessage;

  List<RoutineTask> _stagedWeeklyTasks = [];

  static const List<String> _quickRefinementChips = [
    'Make Sundays rest days',
    'Add 15m break after lunch',
    'No college on Friday',
    'Add 45m workout at 6pm',
    'Set 3 hours study on weekends',
  ];

  @override
  void initState() {
    super.initState();
    _localEngine = widget.localScheduleEngine ?? LocalScheduleEngine();
    _groqService = widget.groqAiAgentService ?? GroqAiAgentService();
    _qwenModelService = widget.qwenCloudModelService ?? QwenCloudModelService();
    _updateEngineStatus();
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  /// Fast active socket probe to check internet access without hanging.
  Future<bool> _checkInternetAccess() async {
    try {
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refreshes network connectivity state and local Qwen 0.5B GGUF model readiness.
  Future<void> _updateEngineStatus() async {
    final isOnline = await _checkInternetAccess();
    final isQwenReady = await _qwenModelService.isModelReady();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _isQwenReady = isQwenReady;
      });
    }
  }

  /// Opens the Valorant-style HUD Offline Model Download & Storage Dialog.
  Future<void> _openModelManagerDialog() async {
    await OfflineModelDownloadDialog.show(
      context,
      modelService: _qwenModelService,
      onModelStatusChanged: _updateEngineStatus,
    );
    await _updateEngineStatus();
  }

  /// Converts raw map task data into strongly typed [RoutineTask] model instances.
  List<RoutineTask> _mapJsonToRoutineTasks(List<Map<String, dynamic>> rawMaps) {
    final now = DateTime.now();

    return rawMaps.asMap().entries.map((entry) {
      final idx = entry.key;
      final t = entry.value;

      final title = t['title'] as String? ?? 'Routine Task';
      final category = t['category'] as String? ?? 'Personal';
      final startHour = (t['startHour'] as num?)?.toInt() ?? 8;
      final startMinute = (t['startMinute'] as num?)?.toInt() ?? 0;
      final duration = (t['durationMinutes'] as num?)?.toInt() ?? 60;

      final daysRaw = t['daysOfWeek'];
      List<int> days = const [1, 2, 3, 4, 5, 6, 7];
      if (daysRaw is List && daysRaw.isNotEmpty) {
        days = daysRaw.map((e) => (e as num).toInt()).where((d) => d >= 1 && d <= 7).toList();
        if (days.isEmpty) days = const [1, 2, 3, 4, 5, 6, 7];
      }

      final startTime = DateTime(now.year, now.month, now.day, startHour, startMinute);

      return RoutineTask(
        id: '${DateTime.now().microsecondsSinceEpoch}_$idx',
        title: title,
        category: category,
        startTime: startTime,
        durationMinutes: duration,
        type: TaskType.routine,
        isCompleted: false,
        updatedAt: DateTime.now().toUtc(),
        daysOfWeek: days,
      );
    }).toList();
  }

  /// Smart execution pipeline for initial schedule generation and multi-turn conversational refinements.
  Future<void> _handleConversationalSubmit([String? overridePrompt]) async {
    final promptText = (overridePrompt ?? _chatInputController.text).trim();
    if (promptText.isEmpty) return;

    final focusScope = FocusScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await _updateEngineStatus();

    // Intercept execution if device is offline and local Qwen engine model is missing
    if (!_isOnline && !_isQwenReady) {
      focusScope.unfocus();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'OFFLINE PROTOCOL REQUIRES ON-DEVICE ENGINE (QWEN-0.5B // 390 MB). INITIALIZE DOWNLOAD?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Color(0xFF1E293B),
            duration: Duration(seconds: 4),
          ),
        );
        await _openModelManagerDialog();
      }
      return;
    }

    HapticFeedback.mediumImpact();
    focusScope.unfocus();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    _chatInputController.clear();

    try {
      final profileRepo = await UserProfileRepository.create();
      final userProfile = profileRepo.getProfile();
      final userProfileContext = userProfile.toAiContextString();

      List<Map<String, dynamic>> rawResult;

      if (_isOnline) {
        // Online Pipeline via Groq Cloud AI
        if (_stagedWeeklyTasks.isEmpty) {
          rawResult = await _groqService.generateRoutineFromPrompt(
            promptText,
            localScheduleEngine: _localEngine,
            userProfileContext: userProfileContext,
          );
        } else {
          rawResult = await _groqService.refineExistingSchedule(
            _stagedWeeklyTasks,
            promptText,
            localScheduleEngine: _localEngine,
            userProfileContext: userProfileContext,
          );
        }
      } else {
        // Offline Pipeline via Local Qwen Engine & Learner Synthesis
        final learner = await LocalAiLearnerService.create();
        final synthesized = await learner.synthesizeLocallyFromPatterns(promptText);

        if (synthesized.isNotEmpty) {
          rawResult = synthesized.map((t) => {
            'title': t.title,
            'category': t.category,
            'startHour': t.startTime.hour,
            'startMinute': t.startTime.minute,
            'durationMinutes': t.durationMinutes,
            'daysOfWeek': t.daysOfWeek,
            'isLearnedLocalAi': true,
          }).toList();
        } else {
          rawResult = _localEngine.parseCustomPrompt(promptText);
        }
      }

      final mappedTasks = _mapJsonToRoutineTasks(rawResult);

      // Automatically distill and record pattern every time ANY engine (Groq, Qwen, Gemini, Local) completes
      LocalAiLearnerService.recordPattern(prompt: promptText, tasks: mappedTasks);

      if (mounted) {
        setState(() {
          _stagedWeeklyTasks = mappedTasks;
          _isProcessing = false;
          _errorMessage = null;
        });

        if (!_isOnline) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('⚡ Generated via Offline Qwen-0.5B On-Device Engine'),
              backgroundColor: Color(0xFFFFAA00),
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

          final synthesizedTasks = synthesized.map((t) {
            return RoutineTask(
              id: '${DateTime.now().microsecondsSinceEpoch}_${t.title.hashCode}',
              title: t.title,
              category: t.category,
              startTime: t.startTime,
              durationMinutes: t.durationMinutes,
              type: TaskType.routine,
              isCompleted: false,
              updatedAt: DateTime.now().toUtc(),
              daysOfWeek: t.daysOfWeek,
            );
          }).toList();

          if (mounted) {
            setState(() {
              _stagedWeeklyTasks = synthesizedTasks;
              _isProcessing = false;
              _errorMessage = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Offline: Generated via Local AI Engine')),
            );
          }
        } catch (_) {
          if (mounted) {
            final fallbackMap = _localEngine.parseCustomPrompt(promptText);
            setState(() {
              _stagedWeeklyTasks = _mapJsonToRoutineTasks(fallbackMap);
              _isProcessing = false;
              _errorMessage = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Offline: Generated via Local AI Engine')),
            );
          }
        }
      } else {
        final errText = e.toString().replaceAll('GroqAiAgentException: ', '').replaceAll('Exception: ', '');
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = errText;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI Assistant Error: $errText'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// Manual task addition for current selected day tab.
  void _handleAddNewTask() {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    const dayNames = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};
    final dayName = dayNames[_selectedDayIndex] ?? 'Day';

    final draftTask = RoutineTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '',
      category: 'Personal',
      startTime: DateTime(now.year, now.month, now.day, 9, 0),
      durationMinutes: 45,
      type: TaskType.routine,
      isCompleted: false,
      updatedAt: DateTime.now().toUtc(),
      daysOfWeek: [_selectedDayIndex],
    );

    StagedTaskCard.showEditTaskDialog(
      context,
      task: draftTask,
      dialogTitle: 'Add Task to $dayName',
      confirmButtonText: 'Add Task',
      autoFocus: false,
      onSave: (configuredTask) {
        setState(() {
          _stagedWeeklyTasks = [..._stagedWeeklyTasks, configuredTask];
        });
        HapticFeedback.selectionClick();
        FocusScope.of(context).unfocus();
      },
    );
  }

  /// Task item update handler.
  void _handleUpdateTask(RoutineTask updated) {
    setState(() {
      _stagedWeeklyTasks = _stagedWeeklyTasks
          .map((t) => t.id == updated.id ? updated : t)
          .toList();
    });
    HapticFeedback.selectionClick();
  }

  /// Task deletion handler.
  void _handleDeleteTask(String taskId) {
    setState(() {
      _stagedWeeklyTasks = _stagedWeeklyTasks.where((t) => t.id != taskId).toList();
    });
    HapticFeedback.mediumImpact();
  }

  /// Opens dialog to confirm routine commitment.
  Future<void> _showApplyConfirmationDialog() async {
    if (_stagedWeeklyTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No staged tasks to apply. Please generate a schedule first.')),
      );
      return;
    }

    bool overwrite = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Apply Schedule to My Week', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You are about to commit ${_stagedWeeklyTasks.length} staged routine tasks to your weekly routine.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              RadioGroup<bool>(
                groupValue: overwrite,
                onChanged: (val) => setDialogState(() => overwrite = val!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      value: true,
                      title: const Text('Replace entire weekly routine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Clears your current daily routine tasks and applies the new schedule', style: TextStyle(fontSize: 11)),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      title: const Text('Merge with existing routines', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Appends new staged tasks without deleting existing tasks', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
              child: const Text('Confirm & Apply'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      _applyFinalSchedule(overwrite);
    }
  }

  /// Writes staged tasks to SQLite database and syncs state.
  Future<void> _applyFinalSchedule(bool overwriteExisting) async {
    setState(() => _isApplying = true);

    try {
      final rawAiTasks = _stagedWeeklyTasks.map((t) => {
        'title': t.title,
        'category': t.category,
        'startHour': t.startTime.hour,
        'startMinute': t.startTime.minute,
        'durationMinutes': t.durationMinutes,
        'daysOfWeek': t.daysOfWeek,
      }).toList();

      await widget.routineRepository.applyAiGeneratedRoutine(
        rawAiTasks: rawAiTasks,
        overwriteExisting: overwriteExisting,
      );

      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Weekly Schedule applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply schedule: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Builds the top Tactical Beacon HUD Chip with guaranteed overflow-free scale-down layout.
  Widget _buildTacticalBeaconChip() {
    final Color beaconColor;
    final String label;

    if (_isOnline) {
      beaconColor = const Color(0xFF00D2D3); // Cyan
      label = '[ONLINE // GROQ_LLAMA_3.3]';
    } else if (_isQwenReady) {
      beaconColor = const Color(0xFFFFAA00); // Amber
      label = '[OFFLINE // QWEN_0.5B_READY]';
    } else {
      beaconColor = const Color(0xFFFF6B6B); // Red
      label = '[OFFLINE // NO_LOCAL_ENGINE]';
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _openModelManagerDialog,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: beaconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: beaconColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: beaconColor,
                    boxShadow: [
                      BoxShadow(
                        color: beaconColor.withValues(alpha: 0.8),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: beaconColor,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.tune_rounded, size: 11, color: beaconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tactical offline banner displayed above command bar when offline.
  Widget _buildTacticalOfflineBanner() {
    if (_isOnline) return const SizedBox.shrink();

    final Color statusColor = _isQwenReady ? const Color(0xFFFFAA00) : const Color(0xFFFF6B6B);
    final String statusText = _isQwenReady
        ? '[TACTICAL OFFLINE MODE // QWEN-0.5B ENGINE READY]'
        : '[TACTICAL OFFLINE MODE // NO ON-DEVICE ENGINE]';

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _openModelManagerDialog,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 14, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: statusColor),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final primaryColor = ThemeController.instance.seedColor;

        // Filter staged tasks for current selected day tab (1 = Mon ... 7 = Sun)
        final dayTasks = _stagedWeeklyTasks
            .where((t) => t.daysOfWeek.contains(_selectedDayIndex))
            .toList();

        // Sort day tasks chronologically
        dayTasks.sort((a, b) {
          final aMins = a.startTime.hour * 60 + a.startTime.minute;
          final bMins = b.startTime.hour * 60 + b.startTime.minute;
          return aMins.compareTo(bMins);
        });

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 2,
            titleSpacing: 8,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AI Schedule Studio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.2),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 1),
                      _buildTacticalBeaconChip(),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: _isApplying || _isProcessing
                        ? null
                        : LinearGradient(
                            colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
                          ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isApplying || _isProcessing ? null : _showApplyConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(58, 32),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _isApplying
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 14),
                    label: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Horizontal 7-Day Day Selector Strip
              _buildSevenDaySelectorStrip(),

              // 2. Main Scrollable Day Task Editor
              Expanded(
                child: _isProcessing
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: primaryColor),
                            const SizedBox(height: 16),
                            const Text('AI is building schedule...', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : dayTasks.isEmpty
                        ? _buildEmptyStateView()
                        : ListView.builder(
                            controller: _previewScrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: dayTasks.length + 1,
                            addRepaintBoundaries: true,
                            addAutomaticKeepAlives: true,
                            itemBuilder: (context, index) {
                              if (index == dayTasks.length) {
                                return _buildAddTaskButton();
                              }
                              final task = dayTasks[index];
                              return StagedTaskCard(
                                key: ValueKey(task.id),
                                task: task,
                                onUpdate: _handleUpdateTask,
                                onDelete: () => _handleDeleteTask(task.id),
                              );
                            },
                          ),
              ),

              // 3. Tactical Offline Banner (when offline)
              _buildTacticalOfflineBanner(),

              // 4. Error Banner (if any)
              if (_errorMessage != null) _buildErrorMessageBanner(),

              // 5. Quick Action Refinement Chips (hidden when keyboard is active)
              if (MediaQuery.of(context).viewInsets.bottom == 0)
                _buildQuickActionChips(),

              // 6. Conversational Refinement Bar
              _buildConversationalInputBar(),
            ],
          ),
        );
      },
    );
  }

  /// Renders 7-Day selector strip with dynamic task count badges.
  Widget _buildSevenDaySelectorStrip() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const dayLabels = [
      {'idx': 1, 'name': 'Mon'},
      {'idx': 2, 'name': 'Tue'},
      {'idx': 3, 'name': 'Wed'},
      {'idx': 4, 'name': 'Thu'},
      {'idx': 5, 'name': 'Fri'},
      {'idx': 6, 'name': 'Sat'},
      {'idx': 7, 'name': 'Sun'},
    ];

    final todayWeekday = DateTime.now().weekday;

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dayLabels.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final day = dayLabels[index];
          final dayIdx = day['idx'] as int;
          final dayName = day['name'] as String;
          final isSelected = _selectedDayIndex == dayIdx;
          final isToday = dayIdx == todayWeekday;

          final count = _stagedWeeklyTasks.where((t) => t.daysOfWeek.contains(dayIdx)).length;

          final primaryColor = ThemeController.instance.seedColor;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedDayIndex = dayIdx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor
                      : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor
                        : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    width: isSelected ? 1.8 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.47),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700),
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.23)
                                    : (isDark ? Colors.white12 : Colors.black12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday
                            ? (isSelected ? const Color(0xFF00D2D3) : Colors.orangeAccent)
                            : (isSelected ? Colors.white.withValues(alpha: 0.7) : Colors.transparent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Empty state view when no tasks are staged for the selected day tab.
  Widget _buildEmptyStateView() {
    const dayNames = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};
    final currentDayName = dayNames[_selectedDayIndex] ?? 'Selected Day';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined, size: 44, color: Colors.grey.withValues(alpha: 0.47)),
            const SizedBox(height: 10),
            Text(
              'No Tasks Scheduled for $currentDayName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the AI prompt below to generate tasks or add a task manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            _buildAddTaskButton(),
          ],
        ),
      ),
    );
  }

  /// Manual task creation button.
  Widget _buildAddTaskButton() {
    const dayNames = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};
    final dayLabel = dayNames[_selectedDayIndex] ?? 'Day';
    final primaryColor = ThemeController.instance.seedColor;

    return OutlinedButton.icon(
      onPressed: _handleAddNewTask,
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: Text('+ Add Task to $dayLabel'),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Error banner rendering.
  Widget _buildErrorMessageBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        ],
      ),
    );
  }

  /// Quick conversational action refinement chips.
  Widget _buildQuickActionChips() {
    final primaryColor = ThemeController.instance.seedColor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _quickRefinementChips.map((chipText) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              label: Text(chipText),
              onPressed: () => _handleConversationalSubmit(chipText),
              backgroundColor: primaryColor.withValues(alpha: 0.08),
              labelStyle: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Conversational bottom input bar.
  Widget _buildConversationalInputBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = ThemeController.instance.seedColor;

    final isRefinement = _stagedWeeklyTasks.isNotEmpty;

    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomPadding = isKeyboardVisible
        ? 8.0
        : (10.0 + MediaQuery.of(context).padding.bottom);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: bottomPadding,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.31 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatInputController,
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => _handleConversationalSubmit(),
              decoration: InputDecoration(
                hintText: isRefinement
                    ? 'Ask AI to refine (e.g., "Add 15m break", "Rest on Sunday")...'
                    : 'Describe your ideal routine (e.g., "Study 3h, gym 1h, college 8:30-1pm")...',
                hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                filled: true,
                fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF0F2F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), primaryColor)],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _isProcessing ? null : () => _handleConversationalSubmit(),
            ),
          ),
        ],
      ),
    );
  }
}
