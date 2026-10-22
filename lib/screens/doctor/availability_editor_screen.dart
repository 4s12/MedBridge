import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Allows a doctor to configure their working hours, slot duration,
/// lunch hour, and working days, persisted to Firestore.
class AvailabilityEditorScreen extends StatefulWidget {
  final Doctor doctor;
  const AvailabilityEditorScreen({super.key, required this.doctor});

  @override
  State<AvailabilityEditorScreen> createState() =>
      _AvailabilityEditorScreenState();
}

class _AvailabilityEditorScreenState extends State<AvailabilityEditorScreen> {
  late int _startHour;
  late int _endHour;
  late int _slotMinutes;
  late int _lunchHour;
  late Set<int> _workingDays; // 1=Mon … 7=Sun
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.doctor.availability;
    _startHour = (a['startHour'] as num?)?.toInt() ?? 9;
    _endHour = (a['endHour'] as num?)?.toInt() ?? 17;
    _slotMinutes = (a['slotMinutes'] as num?)?.toInt() ?? 30;
    _lunchHour = (a['lunchHour'] as num?)?.toInt() ?? 13;
    final rawDays = (a['workingDays'] as List?)
        ?.map((e) => (e as num).toInt())
        .toSet();
    _workingDays = rawDays ?? {1, 2, 3, 4, 5, 6}; // Mon–Sat default
  }

  Future<void> _save() async {
    if (_startHour >= _endHour) {
      showMsg(context, 'Start hour must be before end hour.', error: true);
      return;
    }
    if (_workingDays.isEmpty) {
      showMsg(context, 'Select at least one working day.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await DB.updateAvailability(widget.doctor.id, {
        'startHour': _startHour,
        'endHour': _endHour,
        'slotMinutes': _slotMinutes,
        'lunchHour': _lunchHour,
        'workingDays': _workingDays.toList()..sort(),
      });
      if (mounted) {
        showMsg(context, 'Availability saved!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMsg(context, AuthService.message(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _hourPicker(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: List.generate(24, (i) => i)
              .map((h) => DropdownMenuItem(
                    value: h,
                    child: Text(
                        h == 0 ? '12:00 AM' : Slot(h, 0).label),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _dayChip(int day, String label) {
    final selected = _workingDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: kPrimary.withValues(alpha: 0.2),
      checkmarkColor: kPrimary,
      onSelected: (v) {
        setState(() {
          if (v) {
            _workingDays.add(day);
          } else {
            _workingDays.remove(day);
          }
        });
      },
    );
  }

  List<Slot> get _previewSlots => buildSlots(
        startHour: _startHour,
        endHour: _endHour,
        slotMinutes: _slotMinutes,
        lunchHour: _lunchHour,
      );

  @override
  Widget build(BuildContext context) {
    final preview = _previewSlots;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Availability'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Centered(
        maxWidth: 520,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle('Working Hours'),
            _hourPicker(
                'Start time', _startHour, (v) => setState(() => _startHour = v)),
            _hourPicker(
                'End time', _endHour, (v) => setState(() => _endHour = v)),
            _hourPicker(
                'Lunch break (skipped)',
                _lunchHour,
                (v) => setState(() => _lunchHour = v)),

            const SectionTitle('Slot Duration'),
            DropdownButtonFormField<int>(
              value: _slotMinutes,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [15, 20, 30, 45, 60]
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('$m minutes'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _slotMinutes = v);
              },
            ),
            const SizedBox(height: 20),

            const SectionTitle('Working Days'),
            Wrap(
              spacing: 8,
              children: [
                _dayChip(1, 'Mon'),
                _dayChip(2, 'Tue'),
                _dayChip(3, 'Wed'),
                _dayChip(4, 'Thu'),
                _dayChip(5, 'Fri'),
                _dayChip(6, 'Sat'),
                _dayChip(7, 'Sun'),
              ],
            ),
            const SizedBox(height: 20),

            // Live preview of generated slots
            SectionTitle('Preview (${preview.length} slots/day)'),
            if (preview.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No slots generated. Adjust your settings.'),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: preview
                        .map((s) => Chip(
                              label: Text(s.label,
                                  style: const TextStyle(fontSize: 12)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save),
        label: const Text('Save Availability'),
      ),
    );
  }
}
