// WIDGETS: small reusable UI pieces. They only display what they are given
// and report results back. They never touch state or services.

import 'package:flutter/material.dart';

import '../logic/goal_validation.dart';

/// Asks for a daily goal in minutes.
///
/// Returns the new goal, or null if the user cancelled. Invalid input
/// (0, negative, text) blocks saving and shows a message (AC05).
///
/// When [suggestion] is given, it is offered as an optional starting
/// point based on [averageMinutes] over [observedDays] days (FR05).
Future<int?> showGoalDialog(
  BuildContext context, {
  required String appName,
  int? currentLimit,
  int? suggestion,
  int averageMinutes = 0,
  int observedDays = 0,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _GoalDialog(
      appName: appName,
      currentLimit: currentLimit,
      suggestion: suggestion,
      averageMinutes: averageMinutes,
      observedDays: observedDays,
    ),
  );
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({
    required this.appName,
    required this.currentLimit,
    required this.suggestion,
    required this.averageMinutes,
    required this.observedDays,
  });

  final String appName;
  final int? currentLimit;
  final int? suggestion;
  final int averageMinutes;
  final int observedDays;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    text: widget.currentLimit?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;
    return AlertDialog(
      title: Text('Daily goal for ${widget.appName}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutes per day'),
                validator: validateLimit,
                onFieldSubmitted: (_) => _save(),
              ),
              if (suggestion != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Over the last ${widget.observedDays} days you used this '
                  'app about ${widget.averageMinutes} min a day. '
                  '$suggestion min could be a starting point. It is only a '
                  'suggestion: choose what fits you.',
                ),
                TextButton(
                  onPressed: () => _controller.text = '$suggestion',
                  child: Text('Use $suggestion min'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
