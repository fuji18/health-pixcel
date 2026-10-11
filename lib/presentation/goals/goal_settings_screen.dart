import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_pixcel/domain/goal_input.dart';
import 'package:health_pixcel/domain/models/goals.dart';
import 'package:health_pixcel/presentation/goals/goals_controller.dart';

/// 目標値(歩数・睡眠時間)の設定画面。
class GoalSettingsScreen extends ConsumerStatefulWidget {
  const GoalSettingsScreen({super.key});

  @override
  ConsumerState<GoalSettingsScreen> createState() => _GoalSettingsScreenState();
}

class _GoalSettingsScreenState extends ConsumerState<GoalSettingsScreen> {
  final _stepsController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  String? _stepsError;
  String? _hoursError;
  String? _minutesError;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _stepsController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _initialize(Goals goals) {
    _initialized = true;
    _stepsController.text = goals.steps?.toString() ?? '';
    final sleep = goals.sleepMinutes;
    _hoursController.text = sleep == null ? '' : (sleep ~/ 60).toString();
    _minutesController.text = sleep == null ? '' : (sleep % 60).toString();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(goalsControllerProvider);
    final goals = async.value;
    if (goals != null && !_initialized) _initialize(goals);
    return Scaffold(
      appBar: AppBar(title: const Text('目標の設定')),
      body: goals == null
          ? const Center(
              child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
            )
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('歩数', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('stepsGoalField'),
          controller: _stepsController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_stepsError != null) setState(() => _stepsError = null);
          },
          decoration: InputDecoration(
            labelText: '1 日の歩数',
            suffixText: '歩',
            helperText: '1,000〜100,000 歩。空欄にすると目標なし',
            errorText: _stepsError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Text('睡眠時間', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('sleepHoursField'),
                controller: _hoursController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearSleepErrors(),
                decoration: InputDecoration(
                  labelText: '時間',
                  suffixText: '時間',
                  errorText: _hoursError,
                  errorMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('sleepMinutesField'),
                controller: _minutesController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearSleepErrors(),
                decoration: InputDecoration(
                  labelText: '分',
                  suffixText: '分',
                  errorText: _minutesError,
                  errorMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '3〜12 時間。空欄にすると目標なし',
          style: textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ),
      ],
    );
  }

  void _clearSleepErrors() {
    if (_hoursError != null || _minutesError != null) {
      setState(() {
        _hoursError = null;
        _minutesError = null;
      });
    }
  }

  Future<void> _save() async {
    final steps = parseStepsGoal(_stepsController.text);
    final sleep = parseSleepGoal(
      _hoursController.text,
      _minutesController.text,
    );
    setState(() {
      _stepsError = steps.error;
      _hoursError = sleep.hoursError;
      _minutesError = sleep.minutesError;
    });
    if (steps.error != null ||
        sleep.hoursError != null ||
        sleep.minutesError != null) {
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(goalsControllerProvider.notifier)
        .save(Goals(steps: steps.value, sleepMinutes: sleep.minutes));
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('目標を保存しました')));
      Navigator.of(context).pop();
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('保存できませんでした')));
    }
  }
}
