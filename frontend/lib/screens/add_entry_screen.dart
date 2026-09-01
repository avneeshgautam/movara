import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/exercise.dart';
import '../models/workout_entry.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/movara_colors.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  List<Exercise> _knownExercises = [];
  String _exerciseName = '';
  int _sets = 3;
  int _reps = 10;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.api.fetchExercises().then((list) {
      if (mounted) setState(() => _knownExercises = list);
    }).catchError((_) {
      // Non-fatal: the user can still type a free-text exercise name.
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final weightText = _weightController.text.trim();
      await widget.api.addWorkoutEntry(WorkoutEntry(
        exerciseName: _exerciseName.trim(),
        sets: _sets,
        reps: _reps,
        weightKg: weightText.isEmpty ? null : double.tryParse(weightText),
        performedAt: _date,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log a set')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildExerciseField(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _Stepper(
                      label: 'Sets',
                      value: _sets,
                      onChanged: (v) => setState(() => _sets = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Stepper(
                      label: 'Reps',
                      value: _reps,
                      onChanged: (v) => setState(() => _reps = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg) — optional',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(DateFormat.yMMMd().format(_date)),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes — optional',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseField() {
    return Autocomplete<Exercise>(
      displayStringForOption: (e) => e.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return _knownExercises;
        return _knownExercises.where((e) => e.name.toLowerCase().contains(query));
      },
      onSelected: (e) => setState(() => _exerciseName = e.name),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) => _exerciseName = value,
          decoration: const InputDecoration(
            labelText: 'Exercise',
            hintText: 'e.g. Squats',
            prefixIcon: Icon(Icons.fitness_center),
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Enter an exercise name' : null,
        );
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.movara;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(color: c.textMuted, fontSize: 10, letterSpacing: 1.2),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: c.textSecondary,
                onPressed: value > 1 ? () => onChanged(value - 1) : null,
              ),
              Text(
                '$value',
                style: AppTheme.display(
                  color: c.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: c.accent,
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
